defmodule Rivet.Ecto.ExtendFields do
  defmacro extend_fields(app, key) do
    app = Macro.expand(app, __CALLER__)
    key = Macro.expand(key, __CALLER__)

    for {kind, name, type, opts} <- Application.compile_env(__CALLER__, app, key, []) do
      quote do
        unquote(kind)(unquote(name), unquote(type), unquote(Macro.escape(opts)))
      end
    end
    |> then(fn declarations ->
      quote do
        (unquote_splicing(declarations))
      end
    end)
  end
end
