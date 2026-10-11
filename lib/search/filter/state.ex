defmodule Rivet.Search.Filter.State do
  @moduledoc """

  State shared across filter preparation and query construction.

  Special note:

  * `joins` tracks requested joins
  * `joined` tracks joins already applied

  """

  @type t :: %__MODULE__{
          order: list(),
          values: map(),
          joins: map(),
          joined: map(),
          schema: map(),
          meta: map()
        }

  defstruct order: [], values: %{}, joins: %{}, joined: %{}, schema: %{}, meta: %{}
end
