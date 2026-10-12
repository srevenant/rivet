defmodule Rivet.Search.MixedAuth do
  @moduledoc """

  MixedAuth provides a way to select different search execution paths based on
  authentication or authorization needs, without duplicating that branching
  throughout the search implementation.

  There are two mechanisms available:

  * **Adjust `user_args`** using fixed values or callback functions. This allows
    you to enforce filters, override limits, or modify search behavior without
    requiring separate search modules.

  * **Select different search modules** (e.g., UserSearch and AdminSearch).
    This is recommended when the available columns or overall search capabilities
    differ significantly.

    Alternately: shared search modules work well when the columns remain the
    same, but their behavior, filters, joins, or limits depend on authorization
    context in user_args.

  This module does not authenticate users or verify permissions itself. It routes
  execution based on authorization decisions made by the calling application.

  The caller supplies an auth value (authentication/authn ~ authorization/authz).
  A `nil` value indicates that the required auth was not established and selects
  the unauthed path. Any non-nil value is assumed to have already satisfied the
  required auth level.

  On the unauthorized path, `:none` is then set as the authorization value.

  """
  alias Rivet.Search.Result

  @type search_module :: Rivet.Search.search_module()
  @type auth_error :: Rivet.Search.search_error()
  @type user_args() :: Rivet.Search.user_args()
  @type runtime_opts() :: Rivet.Search.runtime_opts()

  @type auth_type :: atom()
  @type auth_value :: term()

  @type auth_opts :: [
          limit: pos_integer() | auth_adjuster_callback(),
          filter: Rivet.Search.search_filters() | auth_adjuster_callback()
        ]

  @type auth_adjuster_callback :: (user_args(), auth_opts(), runtime_opts(), auth_type() ->
                                     user_args())

  @type mixed_auth_top_callback :: (user_args(), runtime_opts(), auth_type() ->
                                      mixed_auth_final_result())

  @type mixed_auth_continue_callback :: (user_args(), runtime_opts(), auth_type() ->
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
          auth_type :: atom(),
          auth_value(),
          mixed_auth_action(),
          mixed_auth_action()
        ) :: mixed_auth_final_result()

  def mixed_auth_search(args, opts, type, auth, good_action, bad_action \\ :error)

  def mixed_auth_search(args, opts, type, nil, _, bad_action) do
    auth = :none
    args = Map.put(args, type, auth)
    run_auth_action(bad_action, args, opts, type)
  end

  def mixed_auth_search(args, opts, type, auth, good_action, _) do
    args = Map.put(args, type, auth)
    run_auth_action(good_action, args, opts, type)
  end

  ##############################################################################
  # errors first to avoid catching on later patterns

  # hard error
  defp run_auth_action(:error, _, _, type), do: {:error, type}

  # soft error
  defp run_auth_action({:error, e}, _, _, _), do: Result.build_error(e)

  ##############################################################################
  # continue callback
  defp run_auth_action({searcher, func}, args, opts, type)
      when is_atom(searcher) and is_function(func),
      do: run_auth_continue_args(args, opts, searcher, func, type)

  # arg adjustment then continue callback
  defp run_auth_action({searcher, func, auth_opts}, args, opts, type)
      when is_atom(searcher) and is_function(func) and is_list(auth_opts),
      do:
        adjust_auth_args(args, auth_opts, opts, type)
        |> run_auth_continue_args(opts, searcher, func, type)

  # final callback
  defp run_auth_action(func, args, opts, type) when is_function(func) do
    raise_if_not_arity(func, 3, "auth final action #{type}")
    func.(args, opts, type) |> valid_final_auth_result()
  end

  # arg adjustment then search
  defp run_auth_action({searcher, auth_opts}, args, opts, type)
      when is_atom(searcher) and is_list(auth_opts),
      do: adjust_auth_args(args, auth_opts, opts, type) |> searcher.search(opts)

  # arg adjustment then search
  defp run_auth_action(searcher, args, opts, _)
      when is_atom(searcher),
      do: searcher.search(args, opts)

  defp run_auth_action(_, _, _, type),
    do: raise(ArgumentError, "Invalid auth run spec for #{type}")

  ##############################################################################
  defp raise_if_not_arity(func, arity, msg) do
    if not is_function(func, arity) do
      raise ArgumentError, "Invalid callback/#{arity} for #{msg}"
    else
      true
    end
  end

  ##############################################################################
  defp run_auth_continue_args(args, opts, searcher, func, type) do
    raise_if_not_arity(func, 3, "auth continue action #{type}")

    case func.(args, opts, type) do
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
  def adjust_auth_args(user_args, auth_opts, runtime_opts, type) do
    user_args
    |> apply_if_key(:filter, auth_opts, runtime_opts, type)
    |> apply_if_key(:limit, auth_opts, runtime_opts, type)
  end

  defp apply_if_key(args, key, auth_opts, runtime_opts, type) do
    case Keyword.get(auth_opts, key) do
      nil ->
        args

      func when is_function(func) ->
        raise_if_not_arity(func, 4, "auth adjust #{key}")
        func.(args, auth_opts, runtime_opts, type)

      value ->
        Map.put(args, key, value)
    end
  end
end
