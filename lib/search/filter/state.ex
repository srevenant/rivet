defmodule Rivet.Search.Filter.State do
  @type t :: map()
  # note: joins is what needs to be done, joined is what has been done
  defstruct order: [], values: %{}, joins: %{}, joined: %{}, specs: %{}, meta: %{}
end
