defmodule Test.Rivet.TemplateTest do
  use Rivet.Case, async: true
  import ExUnit.CaptureLog

  @test_template "test/support/_template.yml"

  setup_all do
    %{
      path: @test_template
    }
  end

  test "Template", %{path: file} do
    assert {:ok, %{blue: %{narf: "nurse"}, red: %{hello: "nurse"}, green: ["narf"]}} ==
             Rivet.Template.load_file(file)

    assert {:ok, %{blue: %{narf: "nurse"}, red: %{hello: "nurse"}, green: ["narf"]}} ==
             Rivet.Template.load_string(File.read!(file))

    assert {:ok, %{green: ["narf"]}} == Rivet.Template.load_file(file, sections: [:green])
    assert {:error, "Not a Rivet Template: " <> _} = Rivet.Template.load_file("mix.exs")

    assert {:error, "Invalid Template: missing meta sections"} =
             Rivet.Template.load_string("=== rivet-template-v1\n=== blue")

    # ... capture_log isn't working >:(
    capture_log(fn ->
      assert {:error, {%CompileError{}, _}} =
               Rivet.Template.load_string("""
               === rivet-template-v1
               sections:
                  blue: eex-yml
               === blue
               <% narf! %>
               """)
    end)
  end
end
