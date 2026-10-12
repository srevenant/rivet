defmodule Rivet.Search.Tools.MixedAuth do
  @moduledoc """

  MixedAuth provides a way to select different execution paths based on a mix of
  authentication or authorization specific needs, without creating those same
  branches througout the search implementation.

  There are two key nobs to be used:

  * Select different search modules (e.g., UserSearch and AdminSearch). This is
    recommended when the available columns or overall search capabilities differ
    significantly.

    Shared search modules work well when the columns remain the same, but their
    behavior, filters, joins, or limits depend on authorization context.

  * Adjust user_args with fixed values or callback functions.

  This module does not authenticate users or verify permissions itself. It routes
  execution based on authorization decisions made by the calling application.

  The caller supplies an authentication or authorization value. A nil value
  indicates that the required auth was not established and selects the unauthed
  path. Any non-nil value is assumed to have already satisfied the required
  authorization level.

  The unauthorized path then recieves :none as its auth value in user_data.

  """
  alias Rivet.Search.Result

  @type search_module :: Rivet.Search.search_module()
  @type auth_error :: Rivet.Search.search_error()
  @type user_args() :: Rivet.Search.user_args()
  @type runtime_opts() :: Rivet.Search.runtime_opts()

  @type auth_key :: atom()
  @type auth_value :: term()

  @type auth_adjuster_callback :: (user_args(), auth_opts(), runtime_opts() -> user_args())

  @type auth_opts :: [
          limit: pos_integer() | auth_adjuster_callback(),
          filter: Rivet.Search.search_filters() | auth_adjuster_callback()
        ]

  @type mixed_auth_top_callback :: (user_args(), runtime_opts(), auth_key(), auth_value() ->
                                      mixed_auth_final_result())

  @type mixed_auth_continue_callback :: (user_args(), runtime_opts(), auth_key(), auth_value() ->
                                           mixed_auth_result())

  @type mixed_auth_action ::
          search_module()
          | mixed_auth_top_callback()
          | {search_module(), mixed_auth_continue_callback()}
          | {search_module(), mixed_auth_continue_callback(), auth_opts()}
          | {search_module(), auth_opts()}
          | :error
          | auth_error()

  @type mixed_auth_final_result :: {:ok, Result.status_result()} | auth_error()

  @type mixed_auth_continue_result ::
          {:cont, user_args(), runtime_opts()}

  @type mixed_auth_result() :: mixed_auth_final_result() | mixed_auth_continue_result()

  @spec mixed_auth_search(
          user_args(),
          runtime_opts(),
          atom(),
          auth_value(),
          mixed_auth_action(),
          mixed_auth_action()
        ) :: mixed_auth_final_result()

  def mixed_auth_search(args, opts, key, auth, good_action, bad_action \\ :error)

  def mixed_auth_search(args, opts, key, nil, _, bad_action),
    do: run_auth_action(bad_action, args, opts, key, :none)

  def mixed_auth_search(args, opts, key, auth, good_action, _),
    do: run_auth_action(good_action, args, opts, key, auth)

  ##############################################################################
  # errors first to avoid catching on later patterns

  # hard error
  def run_auth_action(:error, _, _, key, _), do: {:error, key}

  # soft error
  def run_auth_action({:error, e}, _, _, _, _), do: Result.build_error(e)

  ##############################################################################
  # continue callback
  def run_auth_action({searcher, func}, args, opts, key, auth)
      when is_atom(searcher) and is_function(func),
      do: run_auth_continue_args(args, opts, searcher, func, key, auth)

  # arg adjustment then continue callback
  def run_auth_action({searcher, func, auth_opts}, args, opts, key, auth)
      when is_atom(searcher) and is_function(func) and is_list(auth_opts),
      do:
        adjust_auth_args(args, auth_opts, opts, key, auth)
        |> run_auth_continue_args(opts, searcher, func, key, auth)

  # final callback
  def run_auth_action(func, args, opts, key, auth) when is_function(func) do
    raise_if_not_arity(func, 4, "auth final action #{key}")
    func.(args, opts, key, auth) |> valid_final_auth_result()
  end

  # arg adjustment then search
  def run_auth_action({searcher, auth_opts}, args, opts, key, auth)
      when is_atom(searcher) and is_list(auth_opts),
      do: adjust_auth_args(args, auth_opts, opts, key, auth) |> searcher.search(opts)

  # arg adjustment then search
  def run_auth_action(searcher, args, opts, key, auth)
      when is_atom(searcher),
      do: Map.put(args, key, auth) |> searcher.search(opts)

  def run_auth_action(_, _, _, key, _),
    do: raise(ArgumentError, "Invalid auth run spec for #{key}")

  ##############################################################################
  defp raise_if_not_arity(func, arity, msg) do
    if not is_function(func, arity) do
      raise ArgumentError, "Invalid callback function/#{arity} for #{msg}"
    else
      true
    end
  end

  ##############################################################################
  defp run_auth_continue_args(args, opts, searcher, func, key, auth) do
    raise_if_not_arity(func, 4, "auth continue action #{key}")

    case func.(args, opts, key, auth) do
      {:cont, args, opts} -> searcher.search(args, opts)
      other -> valid_final_auth_result(other)
    end
  end

  ##############################################################################
  defp valid_final_auth_result({:ok, _} = pass), do: pass
  defp valid_final_auth_result({:error, _} = pass), do: pass

  defp valid_final_auth_result(_other),
    do: raise(ArgumentError, "Invalid result from auth callback")

  ##############################################################################
  def adjust_auth_args(user_args, auth_opts, runtime_opts, key, auth) do
    Map.put(user_args, key, auth)
    |> apply_if_key(:filter, auth_opts, runtime_opts)
    |> apply_if_key(:limit, auth_opts, runtime_opts)
  end

  defp apply_if_key(args, key, auth_opts, runtime_opts) do
    case Keyword.get(auth_opts, key) do
      nil ->
        args

      func when is_function(func) ->
        raise_if_not_arity(func, 3, "auth adjust #{key}")
        func.(args, auth_opts, runtime_opts)

      value ->
        Map.put(args, key, value)
    end
  end
end
