defmodule Rivet.Search.MixedAuth do
  @moduledoc """

  MixedAuth provides a way to route searches based auth context (authentication
  or authorization), keeping access-dependent branching outside the Rivet.Search
  implementation.

  It supports two complementary approaches:

  * **Adjust search behavior** — Apply fixed filters or limits, or use callbacks
    to modify search arguments and runtime options. This works well when the
    searchable columns remain the same, but their behavior, joins, filters, or
    limits depend on auth context.

  * **Select different search modules** — Route searches to modules such as
    `UserSearch` or `AdminSearch`. Separate modules are recommended when the
    available columns or overall search capabilities differ significantly.

  Both approaches can be combined, allowing different auth paths to use different
  search modules, argument adjustments, and callbacks.

  This module does not authenticate users or verify permissions itself. It routes
  execution based on auth decisions made by the calling application.

  A `nil` authorization value selects the unauthed path and is replaced with
  `:none` in user_args. Any non-nil value selects the authorized path and is
  assumed to have satisfied the required access level.

  ## Using MixedAuth

  You can import the module; the only function imported is `mixed_auth_search`, which has as its arguments (in order):

  * `user_args` - Standard Rivet.Search user arguments
  * `runtime_opts` - Standard Rivet.Search runtime options.
  * `auth_type` - Authorization key, typically `:authn` or `:authz`.
  * `auth_value` - Authorization value. `nil` selects `unauthed_action` and inserts `:none` into `user_args`. Any non-nil value selects `authed_action`.
  * `authed_action` - Action to execute when authorization is present.
  * `unauthed_action` — (optional) Action to execute when authorization is absent. Defaults to `:error`.

  ### Action formats

  Both `authed_action` and `unauthed_action` accept the same formats:

  * `SearchModule` - Execute `SearchModule.search/2`.
  * `fun/3` — Execute a `final_result_callback/3` without automatically running a search.
  * `{SearchModule, fun/3}` — Execute a `continue_callback/3`, which may proceed to `SearchModule.search/2`.
  * `{SearchModule, auth_opts}` — Adjust search arguments, then execute `SearchModule.search/2`.
  * `{SearchModule, fun/3, auth_opts}` — Adjust arguments, then execute a `continue_callback/3` that may proceed to the search.
  * `:error` - Return `{:error, type}`
  * `{:error, reason}` - Return a formatted error using `Result.build_error/1`.

  ### Argument Adjustments and `adjustment_callback/4`

  `auth_opts` is a keyword list supporting two optional keys: `:limit` and `:filter`. Each key accepts either a fixed replacement value or an `adjustment_callback/4` function to modify `user_args` dynamically.

  The adjustment callback accepts arguments: `(user_args, auth_opts, runtime_opts, auth_type)`

  It must return the updated arguments map directly, not wrapped in a tuple.

  ### `final_result_callback/3`

  This callback accepts arguments: `(user_args, runtime_opts, auth_type)`

  It must return one of the following, neither of which executes a search:

  * `{:ok, status_result}` — A `Rivet.Search.Result.status_result()` response (which may include a success=false type error).
  * `{:error, reason}` — An top level failure error response.

  ### `continue_callback/3`

  This callback receives the same arguments as `final_result_callback/3` and supports the same final results.

  Additionally, it may return:

  * `{:cont, args, opts}` — Continue execution with `SearchModule.search(args, opts)`.

  This allows the callback to modify both search arguments and runtime options, or terminate early by returning a final result.

  ## Examples

  ### Fixed limit for unauthed.

  This could live on the actual Searcher module, and if the auth is nil will
  then set the search limit to 25 and uses a fixed filter, regardless of user_arg
  preferences.

  ```elixir
    import Rivet.Search.MixedAuth
    ...
    public_filter = [%{n: "visibility", x: :is, v: "public"}]
    def authed_search(user_args, auth) do
      mixed_auth_search(user_args, [], :authz, auth,
        # authed path; go direct to module
        __MODULE__,
        # unauthed path; limit and filter are fixed
        {__MODULE__, limit: 25, filter: public_filter}
      )
    end
  ```

  ### Error if unauthenticated

  If there is no user at all, then return in an error. The default unauthed action
  returns {:error, :authn} in this scenario, so can be left off the function. In
  this scenario the `authn: curent_user` is also inserted into the user args.

  ```elixir
    MixedAuth.mixed_auth_search(args, opts, :authn, current_user, UserSearch)
  ```

  ### Route to different search modules

  Different search modules can provide distinct column definitions, joins,
  and filtering capabilities.

  ```elixir
    MixedAuth.mixed_auth_search(args, opts, :authz, admin_user, AdminSearch, UserSearch)
  ```

  ### Adjust arguments and continue searching

  Adjustment callbacks can modify `user_args` dynamically.

  ```elixir
    limit_adjuster = fn args, _auth_opts, _opts, type ->
      limit = if Map.get(args[type], :role) == :admin, do: 100, else: 25
      Map.put(args, :limit, limit)
    end

    continue = fn args, opts, _type ->
      {:cont, args, Map.put(opts, :matching, true)}
    end

    MixedAuth.mixed_auth_search(
      args, opts, :authn, current_user,
      {UserSearch, continue, [limit: limit_adjuster]}
    )
  ```

  The limit adjustment runs first, followed by the continuation callback.
  Returning `{:cont, args, opts}` executes `UserSearch.search/2` with
  the modified values.

  Alternatively, a continuation callback can return a final `{:ok, result}`
  or `{:error, reason}` to bypass the search entirely.

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
          auth_type(),
          auth_value(),
          authed_action :: mixed_auth_action(),
          unauthed_action :: mixed_auth_action()
        ) :: mixed_auth_final_result()

  def mixed_auth_search(args, opts, type, auth, authed_action, unauthed_action \\ :error)

  def mixed_auth_search(args, opts, type, nil, _, unauthed_action) do
    args = Map.put(args, type, :none)
    run_auth_action(unauthed_action, args, opts, type)
  end

  def mixed_auth_search(args, opts, type, auth, authed_action, _) do
    args = Map.put(args, type, auth)
    run_auth_action(authed_action, args, opts, type)
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
