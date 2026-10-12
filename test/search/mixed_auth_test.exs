defmodule Rivet.Test.Search.MixedAuthTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.MixedAuth

  defmodule Searcher do
    def search(args, opts) do
      {:ok, %{status: %{success: true}, result: {Searcher, %{args: args, opts: opts}}}}
    end
  end

  test "mixed_auth_search routes authorized and unauthorized actions" do
    args = %{filter: [%{n: "name", v: ["Bob"]}], limit: 100}
    opts = %{tracking: true}
    auth = %{id: 123}
    public_filter = [%{n: "status", v: ["active"]}]

    # No authorization defaults to a hard error.
    assert {:error, :authz} =
             MixedAuth.mixed_auth_search(args, opts, :authz, nil, Searcher)

    # An unauthorized action can instead execute a public search.
    assert {:ok, %{result: {Searcher, %{args: %{authz: :none}}}}} =
             MixedAuth.mixed_auth_search(args, opts, :authz, nil, :error, Searcher)

    # Authorized searches pass the authorization into user_args.
    assert {:ok, %{result: {Searcher, %{args: %{authz: ^auth}, opts: ^opts}}}} =
             MixedAuth.mixed_auth_search(args, opts, :authz, auth, Searcher)

    # Tuple form overrides filter and limit before searching.
    action = {Searcher, [filter: public_filter, limit: 10]}

    assert {:ok,
            %{result: {Searcher, %{args: %{authz: ^auth, filter: ^public_filter, limit: 10}}}}} =
             MixedAuth.mixed_auth_search(args, opts, :authz, auth, action)

    # Empty options preserve existing filter and limit.
    args_filter = args.filter

    assert {:ok, %{result: {Searcher, %{args: %{filter: ^args_filter, limit: 100}}}}} =
             MixedAuth.mixed_auth_search(args, opts, :authz, auth, {Searcher, []})

    # Keyword runtime options are also supported.
    assert {:ok, %{result: {Searcher, %{opts: [tracking: true]}}}} =
             MixedAuth.mixed_auth_search(args, [tracking: true], :authz, auth, Searcher)
  end

  test "mixed_auth_search callbacks and argument adjustment" do
    args = %{filter: [], limit: 100}
    opts = %{tracking: true}
    auth = %{id: 123}

    # Top-level callback returns a final result without running a search.
    top = fn a, o, key ->
      assert a == Map.put(args, key, auth)
      assert o == opts
      assert key == :authz
      {:ok, %{status: %{success: true}, result: :handled}}
    end

    assert {:ok, %{result: :handled}} = MixedAuth.mixed_auth_search(args, opts, :authz, auth, top)

    # Continuation callback modifies both arguments and runtime options.
    continue = fn a, o, _key ->
      {:cont, Map.put(a, :limit, 5), Map.put(o, :continued, true)}
    end

    assert {:ok,
            %{result: {Searcher, %{args: %{authz: ^auth, limit: 5}, opts: %{continued: true}}}}} =
             MixedAuth.mixed_auth_search(args, opts, :authz, auth, {Searcher, continue})

    # Argument adjusters run before the continuation callback.
    adjustments = [
      filter: fn a, _, _, _ -> Map.put(a, :filter, [%{n: "status", v: ["active"]}]) end,
      limit: fn a, _, o, _ -> Map.put(a, :limit, if(o.tracking, do: 8, else: 2)) end
    ]

    assert {:ok, %{result: {Searcher, %{args: %{limit: 5, filter: [%{n: "status"}]}}}}} =
             MixedAuth.mixed_auth_search(
               args,
               opts,
               :authz,
               auth,
               {Searcher, continue, adjustments}
             )

    # A continuation callback may return a final result instead of continuing.
    stop = fn _, _, _ ->
      {:ok, %{status: %{success: true}, result: :stopped}}
    end

    assert {:ok, %{result: :stopped}} =
             MixedAuth.mixed_auth_search(args, opts, :authz, auth, {Searcher, stop})
  end

  test "mixed_auth_search error handling" do
    args = %{filter: []}
    opts = %{}
    auth = %{id: 123}

    # Hard and soft errors.
    assert {:error, :authz} =
             MixedAuth.mixed_auth_search(args, opts, :authz, nil, Searcher)

    assert {:ok, %{success: false, reason: "Access denied"}} =
             MixedAuth.mixed_auth_search(
               args,
               opts,
               :authz,
               nil,
               Searcher,
               {:error, "Access denied"}
             )

    # Callback-returned errors propagate.
    fail = fn _, _, _ -> {:error, :blocked} end

    assert {:error, :blocked} = MixedAuth.mixed_auth_search(args, opts, :authz, auth, fail)

    assert {:error, :blocked} =
             MixedAuth.mixed_auth_search(args, opts, :authz, auth, {Searcher, fail})

    # Invalid callback return.
    assert_raise ArgumentError, ~r/Invalid result from auth callback/, fn ->
      MixedAuth.mixed_auth_search(args, opts, :authz, auth, fn _, _, _ -> :bad end)
    end

    # Invalid callback arity.
    assert_raise ArgumentError, ~r/Invalid callback\/3/, fn ->
      MixedAuth.mixed_auth_search(args, opts, :authz, auth, fn _ -> :bad end)
    end

    # Invalid adjuster arity.
    assert_raise ArgumentError, ~r/Invalid callback\/4/, fn ->
      MixedAuth.mixed_auth_search(
        args,
        opts,
        :authz,
        auth,
        {Searcher, [limit: fn _ -> :bad end]}
      )
    end

    # Unknown action.
    assert_raise ArgumentError, ~r/Invalid auth run spec/, fn ->
      MixedAuth.mixed_auth_search(args, opts, :authz, auth, {:unknown, 123})
    end
  end
end
