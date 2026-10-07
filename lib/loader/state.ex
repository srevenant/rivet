defmodule Rivet.Loader.State do
  defstruct opts: [],
            load_file_type: "Rivet",
            load_prefixes: ["Rivet"],
            min_file_ver: 2.1,
            max_file_ver: 2.1,
            deferred: [],
            debug: false,
            defer: nil,
            commit: nil,
            loaded: %{},
            previous: %{},
            limits: nil,
            meta: %{},
            path: nil,
            inits: [],
            # "logs" go here and are returned in the state
            log: []

  @type t :: %__MODULE__{
          opts: map(),
          load_file_type: String.t(),
          load_prefixes: list(String.t()),
          min_file_ver: float(),
          max_file_ver: float(),
          deferred: list(),
          debug: boolean(),
          defer: nil | function(),
          commit: nil | function(),
          loaded: map(),
          previous: map(),
          limits: map() | nil,
          meta: map(),
          path: nil | binary(),
          inits: list(),
          log: list()
        }

  def build(data) do
    struct(__MODULE__, data)
  end
end
