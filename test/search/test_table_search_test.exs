defmodule Test.Core.Db.Network.NetworkIpSearchTest do
  use Test.Support.Core.Case, async: true
  alias Core.Db.NetworkIp.Search

  test "build_query" do
    cols = [
      %{n: "owner", v: ["red"]},
      %{n: "pod", v: ["usca00-a01"]},
      %{n: "status", v: ["assigned"]},
      %{n: "subnet_id", v: [Ecto.UUID.generate()]},
      %{n: "address", v: ["10"]},
      %{n: "notes", v: ["bloop"]}
    ]

    assert {:error, _} = Search.build_search_query([%{n: "pod", v: ["usca00-a01"], x: :no}])
    assert {:ok, _} = Search.build_search_query([%{n: "pod", v: ["usca00-a"]}])
    assert {:ok, _} = Search.build_search_query([%{n: "pod", v: ["usca00"]}])

    assert {:ok,
            %{
              joins: [_, _, _, _, _, _, _],
              order_bys: [_, _, _, _, _, _, _, _],
              wheres: [
                %{expr: {:and, _, [_, _]}}
              ]
            }} = Search.build_search_query(cols)

    assert {:ok, _} = Search.build_search_query([%{n: "pod", v: ["usca00-a"]}])

    assert {:ok, %{success: true}} = Search.authed_search(%{filter: cols})
    assert {:error, :not_found} = Search.authed_search(%{id: Ecto.UUID.generate()})

    org = insert(:org)
    assert {:ok, %{success: true}} = Search.org_search(org, %{filter: []})
    assert {:error, :not_found} = Search.org_search(org, %{id: Ecto.UUID.generate()})
    assert {:error, "auth"} = Search.org_search(org, nil)

    assert {:error, _} = Search.build_search_query([%{n: "address", v: ["10"], x: :narf}])
  end

  test "build_query exclude" do
    cols = [
      %{n: "owner", v: ["red"], x: :no},
      %{n: "status", v: ["assigned"], x: :no},
      %{n: "subnet_id", v: [Ecto.UUID.generate()], x: :no},
      %{n: "address", v: ["10"], x: :no},
      %{n: "notes", v: ["bloop"], x: :no}
    ]

    assert {:ok,
            %{
              joins: [_],
              order_bys: [_, _, _, _, _],
              wheres: [
                %{expr: {:and, _, [_, _]}}
              ]
            }} = Search.build_search_query(cols)
  end
end
