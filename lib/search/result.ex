defmodule Rivet.Search.Result do
  @moduledoc """

  Normalizes search results into Rivet-GraphQL status responses.

  Supports both legacy nested `status` and newer top-level `success` fields
  during the transition. Please stick with only one graphql result shape.

  Authentication errors are returned directly rather than wrapped.

  """

  @doc """
  iex> assert true = has_status?(%{success: 1})
  """
  defguard has_status?(x) when is_map_key(x, :status) or is_map_key(x, :success)

  @doc """
  ```
  iex> status_result({:error, "Unauthenticated"})
  {:error, "Unauthenticated"}

  # this is pass-thru so doesn't get the changes
  iex> status_result({:ok, %{status: %{success: true}, result: :narf}})
  {:ok, %{status: %{success: true}, result: :narf}}

  # these get the extra data
  iex> status_result({:error, "narf"})
  {:ok, %{status: %{success: false, message: "narf"}, success: false, reason: "narf"}}
  iex> status_result({:ok, "narf"})
  {:ok, %{status: %{success: true}, result: "narf", success: true}}
  ```
  """
  @type status_result :: {:ok, map()} | {:error, term()}

  @spec status_result({:ok, term()} | {:error, term()}) :: status_result()

  def status_result({:ok, result} = pass) when has_status?(result), do: pass
  def status_result({:ok, result}), do: build_success(%{result})
  def status_result({:error, error}), do: build_error(error)

  @doc """

  Two arguments is providing additional status params (total, matching, etc)

  Do not bother checking if has_status? already though, as it should be the top

  ```
  iex> status_result({:ok, :narf}, %{boop: "boop"})
  {:ok, %{status: %{success: true, boop: "boop"}, result: :narf, boop: "boop", success: true}}
  iex> status_result({:error, "narf"}, nil)
  {:ok, %{status: %{success: false, message: "narf"}, reason: "narf", success: false}}
  ```
  """
  def status_result({:ok, result}, p), do: build_success(%{result}, p)
  def status_result({:error, error}, _), do: build_error(error)

  @doc """
  ```
  iex> status_results({:ok, %{status: %{success: true}, results: [:a, :b]}})
  {:ok, %{status: %{success: true}, results: [:a, :b]}}
  iex> status_results({:ok, [:a, :b]})
  {:ok, %{status: %{success: true}, results: [:a, :b], success: true}}
  iex> status_results({:ok, "narf"})
  {:ok, %{status: %{success: true}, results: ["narf"], success: true}}
  iex> status_results({:error, "boop"})
  {:ok, %{status: %{success: false, message: "boop"}, reason: "boop", success: false}}
  ```
  """
  @spec status_results({:ok, term()} | {:error, term()}) :: {:ok, map()} | {:error, term()}
  def status_results({:ok, result} = pass) when has_status?(result), do: pass
  def status_results({:ok, results}) when is_list(results), do: build_success(%{results})
  def status_results({:ok, result}), do: build_success(%{results: [result]})
  def status_results({:error, error}), do: build_error(error)

  @doc """

  Two arguments is providing additional status params (total, matching, etc)

  Do not bother checking if has_status? already though, as it should be the top

  ```
  iex> status_results({:ok, [:a]}, %{matching: 1})
  {:ok, %{results: [:a], status: %{matching: 1, success: true}, matching: 1, success: true}}
  iex> status_results({:ok, :a}, %{matching: 1})
  {:ok, %{results: [:a], status: %{matching: 1, success: true}, matching: 1, success: true}}
  iex> status_results({:error, "boop"}, %{})
  {:ok, %{status: %{success: false, message: "boop"}, reason: "boop", success: false}}
  ```
  """

  def status_results({:ok, results}, p) when is_list(results), do: build_success(%{results}, p)
  def status_results({:ok, result}, p), do: build_success(%{results: [result]}, p)
  def status_results({:error, error}, _), do: build_error(error)

  ##############################################################################
  # This is blending two eras of status result so both will work in Absinthe;
  # its not ideal but until everything FE is migrated over is the simplest
  def build_success(base) do
    success = true
    {:ok, Map.merge(base, %{success, status: %{success}})}
  end

  ##############################################################################
  def build_success(base, params) do
    success = true
    status = Map.put(params, :success, success)
    {:ok, Map.merge(status, base) |> Map.put(:status, status)}
  end

  ##############################################################################
  # this passes straight through without a status/success wrapper
  def build_error("Unauthenticated" = msg), do: {:error, msg}

  def build_error(error) do
    success = false
    reason = message = Rivet.Graphql.error_string(error)
    {:ok, %{success, reason, status: %{success, message}}}
  end
end
