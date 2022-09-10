defmodule Phoenix.Component.Declarative do
  @moduledoc false

  ## Reserved assigns

  @reserved_assigns [:__changed__, :__slot__, :inner_block, :myself, :flash, :socket]

  @doc false
  def __reserved__, do: @reserved_assigns

  ## Global

  @global_prefixes ~w(
    phx-
    aria-
    data-
  )
  @globals ~w(
    xml:lang
    xml:base
    onabort
    onautocomplete
    onautocompleteerror
    onblur
    oncancel
    oncanplay
    oncanplaythrough
    onchange
    onclick
    onclose
    oncontextmenu
    oncuechange
    ondblclick
    ondrag
    ondragend
    ondragenter
    ondragleave
    ondragover
    ondragstart
    ondrop
    ondurationchange
    onemptied
    onended
    onerror
    onfocus
    oninput
    oninvalid
    onkeydown
    onkeypress
    onkeyup
    onload
    onloadeddata
    onloadedmetadata
    onloadstart
    onmousedown
    onmouseenter
    onmouseleave
    onmousemove
    onmouseout
    onmouseover
    onmouseup
    onmousewheel
    onpause
    onplay
    onplaying
    onprogress
    onratechange
    onreset
    onresize
    onscroll
    onseeked
    onseeking
    onselect
    onshow
    onsort
    onstalled
    onsubmit
    onsuspend
    ontimeupdate
    ontoggle
    onvolumechange
    onwaiting
    accesskey
    autocapitalize
    autofocus
    class
    contenteditable
    contextmenu
    dir
    draggable
    enterkeyhint
    exportparts
    hidden
    id
    inputmode
    is
    itemid
    itemprop
    itemref
    itemscope
    itemtype
    lang
    nonce
    part
    role
    slot
    spellcheck
    style
    tabindex
    target
    title
    translate
    method
    required
    for
    action
    placeholder
  )

  @doc false
  def __global__?(module, name) when is_atom(module) and is_binary(name) do
    if function_exported?(module, :__global__?, 1) do
      module.__global__?(name) or __global__?(name)
    else
      __global__?(name)
    end
  end

  for prefix <- @global_prefixes do
    def __global__?(unquote(prefix) <> _), do: true
  end

  for name <- @globals do
    def __global__?(unquote(name)), do: true
  end

  def __global__?(_), do: false

  ## Def overrides

  @doc false
  defmacro def(expr, body) do
    quote do
      Kernel.def(unquote(annotate_def(:def, expr)), unquote(body))
    end
  end

  @doc false
  defmacro defp(expr, body) do
    quote do
      Kernel.defp(unquote(annotate_def(:defp, expr)), unquote(body))
    end
  end

  defp annotate_def(kind, expr) do
    case expr do
      {:when, meta, [left, right]} -> {:when, meta, [annotate_call(kind, left), right]}
      left -> annotate_call(kind, left)
    end
  end

  defp annotate_call(_kind, {name, meta, [{:\\, _, _} = arg]}),
    do: {name, meta, [arg]}

  defp annotate_call(kind, {name, meta, [arg]}),
    do: {name, meta, [quote(do: unquote(__MODULE__).__pattern__!(unquote(kind), unquote(arg)))]}

  defp annotate_call(_kind, left),
    do: left

  ## Attrs/slots

  @doc false
  @valid_opts [:global_prefixes]
  def __setup__(module, opts) do
    {prefixes, invalid_opts} = Keyword.pop(opts, :global_prefixes, [])

    prefix_matches =
      for prefix <- prefixes do
        unless String.ends_with?(prefix, "-") do
          raise ArgumentError,
                "global prefixes for #{inspect(module)} must end with a dash, got: #{inspect(prefix)}"
        end

        quote(do: {unquote(prefix) <> _, true})
      end

    if invalid_opts != [] do
      raise ArgumentError, """
      invalid options passed to #{inspect(__MODULE__)}.

      The following options are supported: #{inspect(@valid_opts)}, got: #{inspect(invalid_opts)}
      """
    end

    Module.register_attribute(module, :__attrs__, accumulate: true)
    Module.register_attribute(module, :__slot_attrs__, accumulate: true)
    Module.register_attribute(module, :__slots__, accumulate: true)
    Module.register_attribute(module, :__slot__, accumulate: false)
    Module.register_attribute(module, :__components_calls__, accumulate: true)
    Module.put_attribute(module, :__components__, %{})
    Module.put_attribute(module, :on_definition, __MODULE__)
    Module.put_attribute(module, :before_compile, __MODULE__)

    if prefix_matches == [] do
      []
    else
      prefix_matches ++ [quote(do: {_, false})]
    end
  end

  @doc false
  def __slot__!(module, name, opts, line, file, block_fun) do
    {doc, opts} = Keyword.pop(opts, :doc, nil)

    unless is_binary(doc) or is_nil(doc) or doc == false do
      compile_error!(line, file, ":doc must be a string or false, got: #{inspect(doc)}")
    end

    {required, opts} = Keyword.pop(opts, :required, false)

    unless is_boolean(required) do
      compile_error!(line, file, ":required must be a boolean, got: #{inspect(required)}")
    end

    Module.put_attribute(module, :__slot__, name)

    slot_attrs =
      try do
        block_fun.()
        module |> Module.get_attribute(:__slot_attrs__) |> Enum.reverse()
      after
        Module.put_attribute(module, :__slot__, nil)
        Module.delete_attribute(module, :__slot_attrs__)
      end

    slot = %{
      name: name,
      required: required,
      opts: opts,
      doc: doc,
      line: line,
      attrs: slot_attrs
    }

    validate_slot!(module, slot, line, file)
    Module.put_attribute(module, :__slots__, slot)
    :ok
  end

  defp validate_slot!(module, slot, line, file) do
    slots = Module.get_attribute(module, :__slots__) || []

    if Enum.find(slots, &(&1.name == slot.name)) do
      compile_error!(line, file, """
      a duplicate slot with name #{inspect(slot.name)} already exists\
      """)
    end

    if slot.name == :inner_block and slot.attrs != [] do
      compile_error!(line, file, """
      cannot define attributes in a slot with name #{inspect(slot.name)}
      """)
    end
  end

  @doc false
  def __attr__!(module, name, type, opts, line, file) do
    slot = Module.get_attribute(module, :__slot__)

    if name == :inner_block do
      compile_error!(
        line,
        file,
        "cannot define attribute called :inner_block. Maybe you wanted to use `slot` instead?"
      )
    end

    if type == :global and Keyword.has_key?(opts, :required) do
      compile_error!(line, file, "global attributes do not support the :required option")
    end

    {doc, opts} = Keyword.pop(opts, :doc, nil)

    unless is_binary(doc) or is_nil(doc) or doc == false do
      compile_error!(line, file, ":doc must be a string or false, got: #{inspect(doc)}")
    end

    {required, opts} = Keyword.pop(opts, :required, false)

    unless is_boolean(required) do
      compile_error!(line, file, ":required must be a boolean, got: #{inspect(required)}")
    end

    if required and Keyword.has_key?(opts, :default) do
      compile_error!(line, file, "only one of :required or :default must be given")
    end

    key = if slot, do: :__slot_attrs__, else: :__attrs__
    type = validate_attr_type!(module, key, slot, name, type, line, file)
    validate_attr_opts!(slot, name, opts, line, file)

    if Keyword.has_key?(opts, :default) do
      validate_attr_default!(slot, name, type, opts[:default], line, file)
    end

    attr = %{
      slot: slot,
      name: name,
      type: type,
      required: required,
      opts: opts,
      doc: doc,
      line: line
    }

    Module.put_attribute(module, key, attr)
    :ok
  end

  @builtin_types [:boolean, :integer, :float, :string, :atom, :list, :map, :global]
  @valid_types [:any] ++ @builtin_types

  defp validate_attr_type!(module, key, slot, name, type, line, file) when is_atom(type) do
    attrs = Module.get_attribute(module, key) || []

    cond do
      Enum.find(attrs, fn attr -> attr.name == name end) ->
        compile_error!(line, file, """
        a duplicate attribute with name #{attr_slot(name, slot)} already exists\
        """)

      existing = type == :global && Enum.find(attrs, fn attr -> attr.type == :global end) ->
        compile_error!(line, file, """
        cannot define :global attribute #{inspect(name)} because one \
        is already defined as #{attr_slot(existing.name, slot)}. \
        Only a single :global attribute may be defined\
        """)

      true ->
        :ok
    end

    case Atom.to_string(type) do
      "Elixir." <> _ -> {:struct, type}
      _ when type in @valid_types -> type
      _ -> bad_type!(slot, name, type, line, file)
    end
  end

  defp validate_attr_type!(_module, _key, slot, name, type, line, file) do
    bad_type!(slot, name, type, line, file)
  end

  defp bad_type!(slot, name, type, line, file) do
    compile_error!(line, file, """
    invalid type #{inspect(type)} for attr #{attr_slot(name, slot)}. \
    The following types are supported:

      * any Elixir struct, such as URI, MyApp.User, etc
      * one of #{Enum.map_join(@builtin_types, ", ", &inspect/1)}
      * :any for all other types
    """)
  end

  defp attr_slot(name, nil), do: "#{inspect(name)}"
  defp attr_slot(name, slot), do: "#{inspect(name)} in slot #{inspect(slot)}"

  defp validate_attr_default!(slot, name, type, default, line, file) do
    case {type, default} do
      {_type, nil} ->
        :ok

      {:any, _default} ->
        :ok

      {:string, default} when not is_binary(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:atom, default} when not is_atom(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:boolean, default} when not is_boolean(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:integer, default} when not is_integer(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:float, default} when not is_float(default) ->
        bad_default!(slot, name, type, default, line, file)

      {:list, default} when not is_list(default) ->
        bad_default!(slot, name, type, default, line, file)

      {{:struct, mod}, default} when not is_struct(default) ->
        bad_default!(slot, name, mod, default, line, file)

      {_type, _default} ->
        :ok
    end
  end

  defp bad_default!(slot, name, type, default, line, file) do
    compile_error!(line, file, """
    expected the default value for attr #{attr_slot(name, slot)} to be #{type_with_article(type)}, \
    got: #{inspect(default)}
    """)
  end

  defp validate_attr_opts!(slot, name, opts, line, file) do
    for {key, _} <- opts, message = invalid_attr_message(key, slot) do
      compile_error!(line, file, """
      invalid option #{inspect(key)} for attr #{attr_slot(name, slot)}. #{message}\
      """)
    end
  end

  defp invalid_attr_message(:default, nil), do: nil

  defp invalid_attr_message(:default, _),
    do:
      ":default is not supported inside slot attributes, " <>
        "instead use Map.get/3 with a default value when accessing a slot attribute"

  defp invalid_attr_message(:required, _), do: nil
  defp invalid_attr_message(_key, nil), do: "The supported options are: [:required, :default]"

  defp invalid_attr_message(_key, _slot),
    do: "The supported options inside slots are: [:required]"

  defp compile_error!(line, file, msg) do
    raise CompileError, line: line, file: file, description: msg
  end

  defmacro __pattern__!(kind, arg) do
    {name, 1} = __CALLER__.function
    {_slots, attrs} = register_component!(kind, __CALLER__, name, true)

    fields =
      for %{name: name, required: true, type: {:struct, struct}} <- attrs do
        {name, quote(do: %unquote(struct){})}
      end

    if fields == [] do
      arg
    else
      quote(do: %{unquote_splicing(fields)} = unquote(arg))
    end
  end

  @doc false
  def __on_definition__(env, kind, name, args, _guards, body) do
    case args do
      [_] when body == nil ->
        register_component!(kind, env, name, false)

      _ ->
        attrs = pop_attrs(env)

        validate_misplaced_attrs!(attrs, env.file, fn ->
          case length(args) do
            1 ->
              "could not define attributes for function #{name}/1. " <>
                "Components cannot be dynamically defined or have default arguments"

            arity ->
              "cannot declare attributes for function #{name}/#{arity}. Components must be functions with arity 1"
          end
        end)

        slots = pop_slots(env)

        validate_misplaced_slots!(slots, env.file, fn ->
          case length(args) do
            1 ->
              "could not define slots for function #{name}/1. " <>
                "Components cannot be dynamically defined or have default arguments"

            arity ->
              "cannot declare slots for function #{name}/#{arity}. Components must be functions with arity 1"
          end
        end)
    end
  end

  @after_verify_supported Version.match?(System.version(), ">= 1.14.0-dev")

  @doc false
  defmacro __before_compile__(env) do
    attrs = pop_attrs(env)

    validate_misplaced_attrs!(attrs, env.file, fn ->
      "cannot define attributes without a related function component"
    end)

    slots = pop_slots(env)

    validate_misplaced_slots!(slots, env.file, fn ->
      "cannot define slots without a related function component"
    end)

    components = Module.get_attribute(env.module, :__components__)
    components_calls = Module.get_attribute(env.module, :__components_calls__) |> Enum.reverse()

    names_and_defs =
      for {name, %{kind: kind, attrs: attrs, slots: slots}} <- components do
        attr_defaults =
          for %{name: name, required: false, opts: opts} <- attrs,
              Keyword.has_key?(opts, :default),
              do: {name, Macro.escape(opts[:default])}

        slot_defaults =
          for %{name: name, required: false} <- slots do
            {name, []}
          end

        defaults = attr_defaults ++ slot_defaults

        {global_name, global_default} =
          case Enum.find(attrs, fn attr -> attr.type == :global end) do
            %{name: name, opts: opts} -> {name, Macro.escape(Keyword.get(opts, :default, %{}))}
            nil -> {nil, nil}
          end

        attr_names = for(attr <- attrs, do: attr.name)
        slot_names = for(slot <- slots, do: slot.name)
        known_keys = attr_names ++ slot_names ++ @reserved_assigns

        def_body =
          if global_name do
            quote do
              {assigns, caller_globals} = Map.split(assigns, unquote(known_keys))

              globals =
                case assigns do
                  %{unquote(global_name) => explicit_global_assign} -> explicit_global_assign
                  %{} -> Map.merge(unquote(global_default), caller_globals)
                end

              merged = Map.merge(%{unquote_splicing(defaults)}, assigns)
              super(Phoenix.Component.assign(merged, unquote(global_name), globals))
            end
          else
            quote do
              super(Map.merge(%{unquote_splicing(defaults)}, assigns))
            end
          end

        merge =
          quote do
            Kernel.unquote(kind)(unquote(name)(assigns)) do
              unquote(def_body)
            end
          end

        {{name, 1}, merge}
      end

    {names, defs} = Enum.unzip(names_and_defs)

    overridable =
      if names != [] do
        quote do
          defoverridable unquote(names)
        end
      end

    def_components_ast =
      quote do
        def __components__() do
          unquote(Macro.escape(components))
        end
      end

    def_components_calls_ast =
      if components_calls != [] and @after_verify_supported do
        quote do
          @after_verify {__MODULE__, :__phoenix_component_verify__}

          @doc false
          def __phoenix_component_verify__(module) do
            unquote(__MODULE__).__verify__(module, unquote(Macro.escape(components_calls)))
          end
        end
      end

    {:__block__, [], [def_components_ast, def_components_calls_ast, overridable | defs]}
  end

  defp register_component!(kind, env, name, check_if_defined?) do
    slots = pop_slots(env)
    attrs = pop_attrs(env)

    cond do
      slots != [] or attrs != [] ->
        check_if_defined? and raise_if_function_already_defined!(env, name, slots, attrs)
        register_component_doc(env, kind, slots, attrs)

        for %{name: slot_name, line: line} <- slots,
            Enum.find(attrs, &(&1.name == slot_name)) do
          compile_error!(line, env.file, """
          cannot define a slot with name #{inspect(slot_name)}, as an attribute with that name already exists\
          """)
        end

        components =
          env.module
          |> Module.get_attribute(:__components__)
          # Sort by name as this is used when they are validated
          |> Map.put(name, %{
            kind: kind,
            attrs: Enum.sort_by(attrs, & &1.name),
            slots: Enum.sort_by(slots, & &1.name)
          })

        Module.put_attribute(env.module, :__components__, components)
        Module.put_attribute(env.module, :__last_component__, name)
        {slots, attrs}

      Module.get_attribute(env.module, :__last_component__) == name ->
        %{slots: slots, attrs: attrs} = Module.get_attribute(env.module, :__components__)[name]
        {slots, attrs}

      true ->
        {[], []}
    end
  end

  # Documentation handling

  defp register_component_doc(env, :def, slots, attrs) do
    case Module.get_attribute(env.module, :doc) do
      {_line, false} ->
        :ok

      {line, doc} ->
        Module.put_attribute(env.module, :doc, {line, build_component_doc(doc, slots, attrs)})

      nil ->
        Module.put_attribute(env.module, :doc, {env.line, build_component_doc(slots, attrs)})
    end
  end

  defp register_component_doc(_env, :defp, _slots, _attrs) do
    :ok
  end

  defp build_component_doc(doc \\ "", slots, attrs) do
    [left | right] = String.split(doc, "[INSERT LVATTRDOCS]")

    IO.iodata_to_binary([
      build_left_doc(left),
      build_component_docs(slots, attrs),
      build_right_doc(right)
    ])
  end

  defp build_left_doc("") do
    [""]
  end

  defp build_left_doc(left) do
    [left, ?\n]
  end

  defp build_component_docs(slots, attrs) do
    case {slots, attrs} do
      {[], []} ->
        []

      {slots, [] = _attrs} ->
        [build_slots_docs(slots)]

      {[] = _slots, attrs} ->
        [build_attrs_docs(attrs)]

      {slots, attrs} ->
        [build_attrs_docs(attrs), ?\n, build_slots_docs(slots)]
    end
  end

  defp build_slots_docs(slots) do
    [
      "## Slots",
      ?\n,
      for slot <- slots, slot.doc != false, into: [] do
        slot_attrs =
          for slot_attr <- slot.attrs,
              slot_attr.doc != false,
              slot_attr.slot == slot.name,
              do: slot_attr

        [
          ?\n,
          "* ",
          build_slot_name(slot),
          build_slot_required(slot),
          build_slot_doc(slot, slot_attrs)
        ]
      end
    ]
  end

  defp build_attrs_docs(attrs) do
    [
      "## Attributes",
      ?\n,
      for attr <- attrs, attr.doc != false, into: [] do
        [
          ?\n,
          "* ",
          build_attr_name(attr),
          build_attr_type(attr),
          build_attr_required(attr),
          build_attr_doc_and_default(attr)
        ]
      end
    ]
  end

  defp build_slot_name(%{name: name}) do
    ["`", Atom.to_string(name), "`"]
  end

  defp build_slot_doc(%{doc: nil}, []) do
    []
  end

  defp build_slot_doc(%{doc: doc}, []) do
    [" - ", build_doc(doc)]
  end

  defp build_slot_doc(%{doc: nil}, slot_attrs) do
    ["Accepts attributes: ", build_slot_attrs_docs(slot_attrs)]
  end

  defp build_slot_doc(%{doc: doc}, slot_attrs) do
    [" - ", build_doc(doc), " Accepts attributes: ", build_slot_attrs_docs(slot_attrs)]
  end

  defp build_slot_attrs_docs(slot_attrs) do
    for slot_attr <- slot_attrs do
      [
        ?\n,
        ?\t,
        "* ",
        build_attr_name(slot_attr),
        build_attr_type(slot_attr),
        build_attr_required(slot_attr),
        build_attr_doc_and_default(slot_attr)
      ]
    end
  end

  defp build_slot_required(%{required: true}) do
    [" (required)"]
  end

  defp build_slot_required(_slot) do
    []
  end

  defp build_attr_name(%{name: name}) do
    ["`", Atom.to_string(name), "` "]
  end

  defp build_attr_type(%{type: {:struct, type}}) do
    ["(`", inspect(type), "`)"]
  end

  defp build_attr_type(%{type: type}) do
    ["(`", inspect(type), "`)"]
  end

  defp build_attr_required(%{required: true}) do
    [" (required)"]
  end

  defp build_attr_required(_attr) do
    []
  end

  defp build_attr_doc_and_default(%{doc: nil, opts: [default: default]}) do
    [" - Defaults to `", inspect(default), "`."]
  end

  defp build_attr_doc_and_default(%{doc: doc, opts: [default: default]}) do
    [" - ", build_doc(doc), " Defaults to `", inspect(default), "`."]
  end

  defp build_attr_doc_and_default(%{doc: nil}) do
    []
  end

  defp build_attr_doc_and_default(%{doc: doc}) do
    [" - ", build_doc(doc)]
  end

  defp build_doc(doc) do
    suffix = if String.ends_with?(doc, "."), do: "", else: "."
    [doc, suffix]
  end

  defp build_right_doc("") do
    [""]
  end

  defp build_right_doc(right) do
    [?\n, right]
  end

  defp validate_misplaced_attrs!(attrs, file, message_fun) do
    with [%{line: first_attr_line} | _] <- attrs do
      compile_error!(first_attr_line, file, message_fun.())
    end
  end

  defp validate_misplaced_slots!(slots, file, message_fun) do
    with [%{line: first_slot_line} | _] <- slots do
      compile_error!(first_slot_line, file, message_fun.())
    end
  end

  defp pop_attrs(env) do
    slots = Module.delete_attribute(env.module, :__attrs__) || []
    Enum.reverse(slots)
  end

  defp pop_slots(env) do
    slots = Module.delete_attribute(env.module, :__slots__) || []
    Enum.reverse(slots)
  end

  defp raise_if_function_already_defined!(env, name, slots, attrs) do
    if Module.defines?(env.module, {name, 1}) do
      {:v1, _, meta, _} = Module.get_definition(env.module, {name, 1})

      with [%{line: first_attr_line} | _] <- attrs do
        compile_error!(first_attr_line, env.file, """
        attributes must be defined before the first function clause at line #{meta[:line]}
        """)
      end

      with [%{line: first_slot_line} | _] <- slots do
        compile_error!(first_slot_line, env.file, """
        slots must be defined before the first function clause at line #{meta[:line]}
        """)
      end
    end
  end

  # Verification

  @doc false
  def __verify__(module, component_calls) do
    for %{component: {submod, fun}} = call <- component_calls,
        function_exported?(submod, :__components__, 0),
        component = submod.__components__()[fun],
        do: verify(module, call, component)

    :ok
  end

  defp verify(
         caller_module,
         %{slots: slots, attrs: attrs, root: root} = call,
         %{slots: slots_defs, attrs: attrs_defs} = _component
       ) do
    {attrs, has_global?} =
      Enum.reduce(attrs_defs, {attrs, false}, fn attr_def, {attrs, has_global?} ->
        %{name: name, required: required, type: type} = attr_def
        {value, attrs} = Map.pop(attrs, name)

        case {type, value} do
          # missing required attr
          {_type, nil} when not root and required ->
            message = "missing required attribute \"#{name}\" for component #{component_fa(call)}"
            warn(message, call.file, call.line)

          # missing optional attr, or dynamic attr
          {_type, nil} when root or not required ->
            :ok

          # global attrs cannot be directly used
          {:global, {line, _column, _type_value}} ->
            message =
              "global attribute \"#{name}\" in component #{component_fa(call)} may not be provided directly"

            warn(message, call.file, line)

          {type, {line, _column, type_value}} ->
            if value_ast_to_string = type_mismatch(type, type_value) do
              message =
                "attribute \"#{name}\" in component #{component_fa(call)} must be #{type_with_article(type)}, got: " <>
                  value_ast_to_string

              [warn(message, call.file, line)]
            end
        end

        {attrs, has_global? || type == :global}
      end)

    for {name, {line, _column, _type_value}} <- attrs,
        not (has_global? and __global__?(caller_module, Atom.to_string(name))) do
      message = "undefined attribute \"#{name}\" for component #{component_fa(call)}"
      warn(message, call.file, line)
    end

    undefined_slots =
      Enum.reduce(slots_defs, slots, fn slot_def, slots ->
        %{name: slot_name, required: required, attrs: attrs} = slot_def
        {slot_values, slots} = Map.pop(slots, slot_name)

        case slot_values do
          # missing required slot
          nil when required ->
            message = "missing required slot \"#{slot_name}\" for component #{component_fa(call)}"
            warn(message, call.file, call.line)

          # missing optional slot
          nil ->
            :ok

          # slot with attributes
          _ ->
            has_global? = Enum.any?(attrs, &(&1.type == :global))
            slot_attr_defs = Enum.into(attrs, %{}, &{&1.name, &1})
            required_attrs = for {attr_name, %{required: true}} <- slot_attr_defs, do: attr_name

            for %{attrs: slot_attrs, line: slot_line, root: false} <- slot_values,
                attr_name <- required_attrs,
                not Map.has_key?(slot_attrs, attr_name) do
              message =
                "missing required attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                  "for component #{component_fa(call)}"

              warn(message, call.file, slot_line)
            end

            for %{attrs: slot_attrs} <- slot_values,
                {attr_name, {line, _column, type_value}} <- slot_attrs do
              case slot_attr_defs do
                %{^attr_name => %{type: :global}} ->
                  message =
                    "global attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                      "for component #{component_fa(call)} may not be provided directly"

                  warn(message, call.file, line)

                %{^attr_name => %{type: type}} ->
                  if value_ast_to_string = type_mismatch(type, type_value) do
                    message =
                      "attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                        "for component #{component_fa(call)} must be #{type_with_article(type)}, got: " <>
                        value_ast_to_string

                    warn(message, call.file, line)
                  end

                # undefined attribute
                %{} ->
                  if attr_name == :inner_block or
                       (has_global? and __global__?(caller_module, Atom.to_string(attr_name))) do
                    :ok
                  else
                    message =
                      "undefined attribute \"#{attr_name}\" in slot \"#{slot_name}\" " <>
                        "for component #{component_fa(call)}"

                    warn(message, call.file, line)
                  end
              end
            end
        end

        slots
      end)

    for {slot_name, slot_values} <- undefined_slots,
        %{line: line} <- slot_values,
        not implicit_inner_block?(slot_name, slots_defs) do
      message = "undefined slot \"#{slot_name}\" for component #{component_fa(call)}"
      warn(message, call.file, line)
    end

    :ok
  end

  defp implicit_inner_block?(slot_name, slots_defs) do
    slot_name == :inner_block and length(slots_defs) > 0
  end

  defp type_mismatch(:any, _type_value), do: nil
  defp type_mismatch(_type, :any), do: nil
  defp type_mismatch(type, {type, _value}), do: nil
  defp type_mismatch(:atom, {:boolean, _value}), do: nil
  defp type_mismatch(_type, {_, value}), do: Macro.to_string(value)

  defp component_fa(%{component: {mod, fun}}) do
    "#{inspect(mod)}.#{fun}/1"
  end

  ## Shared helpers

  defp type_with_article(type) when type in [:atom, :integer], do: "an #{inspect(type)}"
  defp type_with_article(type), do: "a #{inspect(type)}"

  # TODO: Provide column information in error messages
  defp warn(message, file, line) do
    IO.warn(message, file: file, line: line)
  end
end
