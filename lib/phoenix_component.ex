defmodule Phoenix.Component do
  @moduledoc ~S'''
  API for function components.

  A function component is any function that receives
  an assigns map as argument and returns a rendered
  struct built with [the `~H` sigil](`Phoenix.LiveView.Helpers.sigil_H/2`).

  Here is an example:

      defmodule MyComponent do
        use Phoenix.Component

        # Optionally also bring the HTML helpers
        # use Phoenix.HTML

        def greet(assigns) do
          ~H"""
          <p>Hello, <%= assigns.name %></p>
          """
        end
      end

  The component can be invoked as a regular function:

      MyComponent.greet(%{name: "Jane"})

  But it is typically invoked using the function component
  syntax from the `~H` sigil:

      ~H"""
      <MyComponent.greet name="Jane" />
      """

  If the `MyComponent` module is imported or if the function
  is defined locally, you can skip the module name:

      ~H"""
      <.greet name="Jane" />
      """

  Similar to any HTML tag inside the `~H` sigil, you can
  interpolate attributes values too:

      ~H"""
      <.greet name={@user.name} />
      """

  You can learn more about the `~H` sigil [in its documentation](`Phoenix.LiveView.Helpers.sigil_H/2`).

  ## `use Phoenix.Component`

  Modules that define function components should call
  `use Phoenix.Component` at the top. Doing so will import
  the functions from both `Phoenix.LiveView` and
  `Phoenix.LiveView.Helpers` modules. `Phoenix.LiveView`
  and `Phoenix.LiveComponent` automatically invoke
  `use Phoenix.Component` for you.

  You must avoid defining a module for each component. Instead,
  we should use modules to group side-by-side related function
  components.

  ## Assigns

  While inside a function component, you must use `Phoenix.LiveView.assign/3`
  and `Phoenix.LiveView.assign_new/3` to manipulate assigns,
  so that LiveView can track changes to the assigns values.
  For example, let's imagine a component that receives the first
  name and last name and must compute the name assign. One option
  would be:

      def show_name(assigns) do
        assigns = assign(assigns, :name, assigns.first_name <> assigns.last_name)

        ~H"""
        <p>Your name is: <%= @name %></p>
        """
      end

  However, when possible, it may be cleaner to break the logic over function
  calls instead of precomputed assigns:

      def show_name(assigns) do
        ~H"""
        <p>Your name is: <%= full_name(@first_name, @last_name) %></p>
        """
      end

      defp full_name(first_name, last_name), do: first_name <> last_name

  Another example is making an assign optional by providing
  a default value:

      def field_label(assigns) do
        assigns = assign_new(assigns, :help, fn -> nil end)

        ~H"""
        <label>
          <%= @text %>

          <%= if @help do %>
            <span class="help"><%= @help %></span>
          <% end %>
        </label>
        """
      end

  ## Slots

  Slots is a mechanism to give HTML blocks to function components
  as in regular HTML tags.

  ### Default slots

  Any content you pass inside a component is assigned to a default slot
  called `@inner_block`. For example, imagine you want to create a button
  component like this:

      <.button>
        This renders <strong>inside</strong> the button!
      </.button>

  It is quite simple to do so. Simply define your component and call
  `render_slot(@inner_block)` where you want to inject the content:

      def button(assigns) do
        ~H"""
        <button class="btn">
          <%= render_slot(@inner_block) %>
        </button>
        """
      end

  In a nutshell, the contents given to the component is assigned to
  the `@inner_block` assign and then we use `Phoenix.LiveView.Helpers.render_slot/2`
  to render it.

  You can even have the component give a value back to the caller,
  by using the special attribute `:let` (note the leading `:`).
  Imagine this component:

      def unordered_list(assigns) do
        ~H"""
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, entry) %></li>
          <% end %>
        </ul>
        """
      end

  And now you can invoke it as:

      <.unordered_list :let={entry} entries={~w(apple banana cherry)}>
        I like <%= entry %>
      </.unordered_list>

  You can also pattern match the arguments provided to the render block. Let's
  make our `unordered_list` component fancier:

      def unordered_list(assigns) do
        ~H"""
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, %{entry: entry, gif_url: random_gif()}) %></li>
          <% end %>
        </ul>
        """
      end

  And now we can invoke it like this:

      <.unordered_list :let={%{entry: entry, gif_url: url}}>
        I like <%= entry %>. <img src={url} />
      </.unordered_list>

  ### Named slots

  Besides `@inner_block`, it is also possible to pass named slots
  to the component. For example, imagine that you want to create
  a modal component. The modal component has a header, a footer,
  and the body of the modal, which we would use like this:

      <.modal>
        <:header>
          This is the top of the modal.
        </:header>

        This is the body - everything not in a
        named slot goes to @inner_block.

        <:footer>
          <button>Save</button>
        </:footer>
      </.modal>

  The component itself could be implemented like this:

      def modal(assigns) do
        ~H"""
        <div class="modal">
          <div class="modal-header">
            <%= render_slot(@header) %>
          </div>

          <div class="modal-body">
            <%= render_slot(@inner_block) %>
          </div>

          <div class="modal-footer">
            <%= render_slot(@footer) %>
          </div>
        </div>
        """
      end

  If you want to make the `@header` and `@footer` optional,
  you can assign them a default of an empty list at the top:

      def modal(assigns) do
        assigns =
          assigns
          |> assign_new(:header, fn -> [] end)
          |> assign_new(:footer, fn -> [] end)

        ~H"""
        <div class="modal">
          ...
      end

  ### Named slots with attributes

  It is also possible to pass the same named slot multiple
  times and also give attributes to each of them.

  If multiple slot entries are defined for the same slot,
  `render_slot/2` will automatically render all entries,
  merging their contents. But sometimes we want more fine
  grained control over each individual slot, including access
  to their attributes. Let's see an example. Imagine we want
  to implement a table component

  For example, imagine a table component:

      <.table rows={@users}>
        <:col :let={user} label="Name">
          <%= user.name %>
        </:col>

        <:col :let={user} label="Address">
          <%= user.address %>
        </:col>
      </.table>

  At the top level, we pass the rows as an assign and we define
  a `:col` slot for each column we want in the table. Each
  column also has a `label`, which we are going to use in the
  table header.

  Inside the component, you can render the table with headers,
  rows, and columns:

      def table(assigns) do
        ~H"""
        <table>
          <tr>
            <%= for col <- @col do %>
              <th><%= col.label %></th>
            <% end %>
          </tr>
          <%= for row <- @rows do %>
            <tr>
              <%= for col <- @col do %>
                <td><%= render_slot(col, row) %></td>
              <% end %>
            </tr>
          <% end %>
        </table>
        """
      end

  Each named slot (including the `@inner_block`) is a list of maps,
  where the map contains all slot attributes, allowing us to access
  the label as `col.label`. This gives us complete control over how
  we render them.

  ## Attributes
  TODO

  ### Global Attributes

  Global attributes may be provided to any component that declares a
  `:global` attribute. By default, the supported global attributes are
  those common to all HTML elements. The full list can be found
  [here](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes)

  Custom attribute prefixes can be provided by the caller module with
  the `:global_prefixes` option to `use Phoenix.Component`. For example, the
  following would allow Alpine JS annotations, such as `x-on:click`,
  `x-data`, etc:

      use Phoenix.Component, global_prefixes: ~w(x-)
  '''

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

  @doc false
  def __reserved_assigns__, do: [:__changed__, :__slot__, :inner_block, :myself, :flash, :socket]

  @doc false
  defmacro __using__(opts \\ []) do
    conditional =
      if __CALLER__.module != Phoenix.LiveView.Helpers do
        quote do: import(Phoenix.LiveView.Helpers)
      end

    imports =
      quote bind_quoted: [opts: opts] do
        import Kernel, except: [def: 2, defp: 2]
        import Phoenix.Component
        import Phoenix.LiveView

        @doc false
        for prefix <- Phoenix.Component.__setup__(__MODULE__, opts) do
          def __global__?(unquote(prefix) <> _), do: true
        end

        def __global__?(_), do: false
      end

    [conditional, imports]
  end

  @doc false
  @valid_opts [:global_prefixes]
  def __setup__(module, opts) do
    {prefixes, invalid_opts} = Keyword.pop(opts, :global_prefixes, [])

    for prefix <- prefixes do
      unless String.ends_with?(prefix, "-") do
        raise ArgumentError,
              "global prefixes for #{inspect(module)} must end with a dash, got: #{inspect(prefix)}"
      end
    end

    if invalid_opts != [] do
      raise ArgumentError, """
      invalid options passed to #{inspect(__MODULE__)}.

      The following options are supported: #{inspect(@valid_opts)}, got: #{inspect(invalid_opts)}
      """
    end

    Module.register_attribute(module, :__attrs__, accumulate: true)
    Module.register_attribute(module, :__components_calls__, accumulate: true)
    Module.put_attribute(module, :__components__, %{})
    Module.put_attribute(module, :on_definition, __MODULE__)
    Module.put_attribute(module, :before_compile, __MODULE__)

    prefixes
  end

  @doc """
  TODO.

  ## Options

    * `:required` - TODO
    * `:default` - TODO

  ## Validations

  LiveView performs some validation of attributes via the `:live_view`
  compiler. When attributes are defined, LiveView will warn at compilation
  time on the caller if:

    * if a required attribute of a component is missing

    * if an unknown attribute is given

    * if you specify a literal attribute (such as `value="string"` or `value`,
      but not `value={expr}`) and the type does not match

  Livebook does not perform any validation at runtime. This means the type
  information is mostly used for documentation and reflection purposes.

  On the side of the LiveView component itself, defining attributes provides
  the following quality of life improvements:

    * The default value of all attributes will be added to the `assigns`
      map upfront

    * Required struct types are annotated and emit compilation warnings.
      For example, if you specify `attr :user, User, required: true` and
      then you write `@user.non_valid_field` in your template, a warning
      will be emitted

  This list may increase in the future.
  """
  defmacro attr(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      Phoenix.Component.__attr__!(__MODULE__, name, type, opts, __ENV__.line, __ENV__.file)
    end
  end

  @doc false
  def __attr__!(module, name, type, opts, line, file) do
    cond do
      not is_atom(name) ->
        compile_error!(line, file, "attribute names must be atoms, got: #{inspect(name)}")

      not is_list(opts) ->
        compile_error!(line, file, """
        expected attr/3 to receive keyword list of options, but got #{inspect(opts)}\
        """)

      type == :global and Keyword.has_key?(opts, :required) ->
        compile_error!(line, file, "global attributes do not support the :required option")

      true ->
        :ok
    end

    {required, opts} = Keyword.pop(opts, :required, false)

    unless is_boolean(required) do
      compile_error!(line, file, ":required must be a boolean, got: #{inspect(required)}")
    end

    if required and Keyword.has_key?(opts, :default) do
      compile_error!(line, file, "only one of :required or :default must be given")
    end

    type = validate_attr_type!(module, name, type, line, file)
    validate_attr_opts!(name, opts, line, file)

    Module.put_attribute(module, :__attrs__, %{
      name: name,
      type: type,
      required: required,
      opts: opts,
      line: line
    })
  end

  @builtin_types [:boolean, :integer, :float, :string, :atom, :list, :map, :global]
  @valid_types [:any] ++ @builtin_types

  defp validate_attr_type!(module, name, type, line, file) when is_atom(type) do
    attrs = get_attrs(module)

    cond do
      Enum.find(attrs, fn attr -> attr.name == name end) ->
        compile_error!(line, file, """
        a duplicate attribute with name #{inspect(name)} already exists\
        """)

      existing = type == :global && Enum.find(attrs, fn attr -> attr.type == :global end) ->
        compile_error!(line, file, """
        cannot define global attribute #{inspect(name)} because one is already defined under #{inspect(existing.name)}.

        Only a single global attribute may be defined.
        """)

      true ->
        :ok
    end

    case Atom.to_string(type) do
      "Elixir." <> _ -> {:struct, type}
      _ when type in @valid_types -> type
      _ -> bad_type!(name, type, line, file)
    end
  end

  defp validate_attr_type!(_module, name, type, line, file) do
    bad_type!(name, type, line, file)
  end

  defp compile_error!(line, file, msg) do
    raise CompileError, line: line, file: file, description: msg
  end

  defp bad_type!(name, type, line, file) do
    compile_error!(line, file, """
    invalid type #{inspect(type)} for attr #{inspect(name)}. \
    The following types are supported:

      * any Elixir struct, such as URI, MyApp.User, etc
      * one of #{Enum.map_join(@builtin_types, ", ", &inspect/1)}
      * :any for all other types
    """)
  end

  @valid_opts [:required, :default]
  defp validate_attr_opts!(name, opts, line, file) do
    for {key, _} <- opts, key not in @valid_opts do
      compile_error!(line, file, """
      invalid option #{inspect(key)} for attr #{inspect(name)}. \
      The supported options are: #{inspect(@valid_opts)}
      """)
    end
  end

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

  defp annotate_call(_kind, {name, meta, [{:\\, _, _} = arg]}), do: {name, meta, [arg]}

  defp annotate_call(kind, {name, meta, [arg]}),
    do: {name, meta, [quote(do: unquote(__MODULE__).__pattern__!(unquote(kind), unquote(arg)))]}

  defp annotate_call(_kind, left),
    do: left

  defmacro __pattern__!(kind, arg) do
    {name, 1} = __CALLER__.function
    attrs = register_component!(kind, __CALLER__, name, true)

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
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    attrs = pop_attrs(env)

    validate_misplaced_attrs!(attrs, env.file, fn ->
      "cannot define attributes without a related function component"
    end)

    components = Module.get_attribute(env.module, :__components__)
    components_calls = Module.get_attribute(env.module, :__components_calls__) |> Enum.reverse()

    names_and_defs =
      for {name, %{kind: kind, attrs: attrs}} <- components do
        defaults =
          for %{name: name, required: false, opts: opts} <- attrs,
              Keyword.has_key?(opts, :default) do
            {name, Macro.escape(opts[:default])}
          end

        {global_name, global_default} =
          case Enum.find(attrs, fn attr -> attr.type == :global end) do
            %{name: name, opts: opts} -> {name, Macro.escape(Keyword.get(opts, :default, %{}))}
            nil -> {nil, nil}
          end

        known_keys = for(attr <- attrs, do: attr.name) ++ __reserved_assigns__()

        def_body =
          if global_name do
            quote do
              {assigns, caller_globals} = Map.split(assigns, unquote(known_keys))
              globals = Map.merge(unquote(global_default), caller_globals)
              merged = Map.merge(%{unquote_splicing(defaults)}, assigns)
              super(Phoenix.LiveView.assign(merged, unquote(global_name), globals))
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
      if components_calls != [] do
        quote do
          def __components_calls__() do
            unquote(Macro.escape(components_calls))
          end
        end
      end

    {:__block__, [], [def_components_ast, def_components_calls_ast, overridable | defs]}
  end

  defp register_component!(kind, env, name, check_if_defined?) do
    attrs = pop_attrs(env)

    cond do
      attrs != [] ->
        check_if_defined? and raise_if_function_already_defined!(env, name, attrs)

        components =
          env.module
          |> Module.get_attribute(:__components__)
          # Sort by name as this is used when they are validated
          |> Map.put(name, %{kind: kind, attrs: Enum.sort_by(attrs, & &1.name)})

        Module.put_attribute(env.module, :__components__, components)
        Module.put_attribute(env.module, :__last_component__, name)
        attrs

      Module.get_attribute(env.module, :__last_component__) == name ->
        Module.get_attribute(env.module, :__components__)[name].attrs

      true ->
        []
    end
  end

  defp validate_misplaced_attrs!(attrs, file, message_fun) do
    with [%{line: first_attr_line} | _] <- attrs do
      compile_error!(first_attr_line, file, message_fun.())
    end
  end

  defp get_attrs(module) do
    Module.get_attribute(module, :__attrs__) || []
  end

  defp pop_attrs(env) do
    attrs =
      env.module
      |> Module.get_attribute(:__attrs__)
      |> Enum.reverse()

    Module.delete_attribute(env.module, :__attrs__)
    attrs
  end

  defp raise_if_function_already_defined!(env, name, attrs) do
    if Module.defines?(env.module, {name, 1}) do
      {:v1, _, meta, _} = Module.get_definition(env.module, {name, 1})
      [%{line: first_attr_line} | _] = attrs

      compile_error!(first_attr_line, env.file, """
      attributes must be defined before the first function clause at line #{meta[:line]}
      """)
    end
  end
end
