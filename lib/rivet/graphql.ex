defmodule Rivet.Graphql do
  @moduledoc """
  Helper functions for Absinthe resolvers.
  """
  require Logger
  import Rivet.Utils.Ecto.Errors, only: [convert_error_changeset: 1]

  @doc """
  iex> current_hostname(%{context: %{hostname: "narf"}})
  {:ok, "narf"}
  iex> current_hostname(:nope)
  {:error, "No Host on session"}
  """
  def current_hostname(%{context: %{hostname: h}}) when not is_nil(h), do: {:ok, h}
  def current_hostname(_), do: {:error, "No Host on session"}

  @doc """
  iex> optional_arg(%{}, :narf)
  []
  iex> optional_arg(%{narf: :something}, :narf)
  [narf: :something]
  """
  def optional_arg(map, arg) do
    case Map.get(map, arg) do
      nil -> []
      value -> [{arg, value}]
    end
  end

  @doc """
  iex> ok_as_list({:error, "Nothing found"})
  {:ok, []}
  iex> ok_as_list({:error, :not_found})
  {:ok, []}
  iex> ok_as_list({:ok, :narf})
  {:ok, [:narf]}
  iex> ok_as_list({:error, :narf})
  {:error, :narf}
  """
  def ok_as_list({:error, :not_found}), do: {:ok, []}
  def ok_as_list({:error, "Nothing found"}), do: {:ok, []}
  def ok_as_list({:ok, result}), do: {:ok, [result]}
  def ok_as_list(pass), do: pass

  def parse_enum(%{value: value}, enum) do
    enum.cast(value)
  end

  def parse_enum(_, _), do: :error

  @doc """
  iex> parse_atom(%{value: "narf"})
  {:ok, :narf}
  iex> parse_atom(%{value: 10})
  :error
  iex> parse_atom(:narf)
  :error
  """
  def parse_atom(%{value: value}) do
    {:ok, String.to_existing_atom(value)}
  rescue
    _ ->
      :error
  end

  def parse_atom(_), do: :error

  ##############################################################################
  @doc """
  iex> error_string([{:error, :authz}])
  "Unauthorized"
  iex> error_string("narf")
  "narf"
  iex> error_string(:authn)
  "Unauthenticated"
  iex> error_string(:authn)
  "Unauthenticated"
  iex> error_string(:narf)
  "narf"
  iex> error_string({:nobody, :expects})
  "unexpected error, see logs"
  """
  @std_errors %{
    authn: "Unauthenticated",
    authz: "Unauthorized",
    args: "Invalid Arguments",
    not_found: "Nothing found"
  }
  def error_string(errs) when is_list(errs) do
    Enum.map(errs, &error_string/1)
    |> Enum.join(",")
  end

  def error_string({:error, err}) when is_map_key(@std_errors, err), do: @std_errors[err]

  def error_string({:error, str}) when is_binary(str), do: str
  def error_string(%Ecto.Changeset{} = chgset), do: convert_error_changeset(chgset)

  def error_string({:error, %Ecto.Changeset{} = chgset}), do: convert_error_changeset(chgset)

  def error_string(reason) when is_binary(reason), do: reason
  def error_string(reason) when is_atom(reason), do: @std_errors[reason] || "#{reason}"

  def error_string(unexpected) do
    Logger.error("unexpected graphql error", error: inspect(unexpected))
    "unexpected error, see logs"
  end

  ##############################################################################
  @doc """
  iex> graphql_result({:ok, :narf})
  {:ok, :narf}
  iex> graphql_result({:error, :args}, :narf)
  {:error, "Invalid Arguments"}
  """
  def graphql_result(x, method \\ nil)
  def graphql_result({:ok, _} = pass, _), do: pass
  def graphql_result({:error, reason}, method), do: graphql_error(method, reason)

  ##############################################################################
  @doc """
  iex> graphql_status_result({:error, "Unauthenticated"})
  {:error, "Unauthenticated"}
  iex> graphql_status_result({:ok, %{success: true, result: :narf}})
  {:ok, %{success: true, result: :narf}}
  iex> graphql_status_result({:ok, %{success: true, result: :narf}}, :narf)
  {:ok, %{success: true, narf: :narf}}
  iex> graphql_status_result({:ok, %{success: false, reason: :narf}})
  {:ok, %{success: false, reason: :narf}}
  iex> graphql_status_result({:ok, 100})
  {:ok, %{success: true, result: 100}}
  iex> graphql_status_result({:ok, 100}, :narf)
  {:ok, %{narf: 100, success: true}}
  iex> graphql_status_result({:error, :authz})
  {:ok, %{reason: "Unauthorized", success: false}}
  """
  def graphql_status_result(state, key \\ nil)

  def graphql_status_result({:error, "Unauthenticated"} = pass, _), do: pass

  def graphql_status_result({:ok, %{success: true}} = pass, nil), do: pass

  def graphql_status_result({:ok, %{success: true, result: result} = r}, key),
    do: {:ok, Map.delete(r, :result) |> Map.put(key, result)}

  def graphql_status_result({:ok, %{success: _}} = pass, _), do: pass
  def graphql_status_result({:ok, result}, nil), do: {:ok, %{success: true, result: result}}

  def graphql_status_result({:ok, result}, key),
    do: {:ok, Map.new([{:success, true}, {key, result}])}

  def graphql_status_result({:error, err}, _),
    do: {:ok, %{success: false, reason: error_string(err)}}

  def graphql_status_result({:error, err, _opts}, _),
    do: {:ok, %{success: false, reason: error_string(err)}}

  ##############################################################################
  @doc """
  Handle multi-results with total/matching tallys

  iex> graphql_status_results({:ok, %{success: true, results: :narf}})
  {:ok, %{success: true, results: :narf}}
  iex> graphql_status_results({:ok, %{success: true, results: :narf}, :narf}, :key)
  {:ok, %{success: true, results: :narf, key: :narf}}
  iex> graphql_status_results({:ok, %{success: true, results: :narf}}, :results)
  {:ok, %{success: true, results: :narf}}
  iex> graphql_status_results({:ok, %{success: true, results: :narf}}, :narf)
  {:ok, %{success: true, narf: :narf}}
  iex> graphql_status_results({:ok, [:narf]}, :narf)
  {:ok, %{success: true, narf: [:narf], total: 1, matching: 1}}
  iex> graphql_status_results({:ok, :narf}, :narf)
  {:ok, %{success: true, narf: [:narf], total: 1, matching: 1}}
  iex> graphql_status_results({:error, :authn})
  {:ok, %{success: false, reason: "Unauthenticated"}}
  """
  def graphql_status_results(x, key \\ :results)

  def graphql_status_results({:ok, meta, r}, key),
    do: {:ok, Map.put(meta, :success, true) |> Map.put(key, r)}

  def graphql_status_results({:ok, %{results: _, success: _}} = pass, :results), do: pass

  def graphql_status_results({:ok, %{results: r, success: _} = m}, key),
    do: {:ok, Map.delete(m, :results) |> Map.put(key, r)}

  def graphql_status_results({:ok, r}, key) when is_list(r),
    do: {:ok, %{success: true, total: length(r), matching: length(r)} |> Map.put(key, r)}

  def graphql_status_results({:ok, r}, key),
    do: {:ok, %{success: true, total: 1, matching: 1} |> Map.put(key, [r])}

  def graphql_status_results(other, key), do: graphql_status_result(other, key)

  ##############################################################################
  def graphql_error(method, err, logargs \\ []) do
    reason = error_string(err)
    graphql_log(method, [failure: reason] ++ logargs)
    {:error, reason}
  end

  ##############################################################################
  @doc """
  iex> graphql_log("narf")
  :ok
  iex> graphql_log(nil)
  :ok
  """
  def graphql_log(method, args \\ [])

  def graphql_log(nil, _), do: :ok

  def graphql_log(method, args), do: Logger.info("graphql #{method}", args)
end
