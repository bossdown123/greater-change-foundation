defmodule Gcf.RichTextTest do
  use ExUnit.Case, async: true
  alias Gcf.Admin.RichText
  defp doc(content), do: "gcf-richtext:" <> Jason.encode!(%{type: "doc", content: content})

  test "legacy prose and rich formatting retain text" do
    assert RichText.valid?("Old story", 100)

    value =
      doc([
        %{type: "paragraph", content: [%{type: "text", text: "Hello", marks: [%{type: "bold"}]}]}
      ])

    assert RichText.valid?(value, 10)
    assert RichText.text(value) == "Hello"
    refute RichText.valid?(value, 4)
  end

  test "only library figures and safe links are accepted" do
    id = String.duplicate("a", 32)

    figure = %{
      type: "gcfFigure",
      attrs: %{mediaId: id, alt: "Community"},
      content: [%{type: "text", text: "Food drive"}]
    }

    value = doc([figure, figure])
    assert RichText.valid?(value, 100)
    assert RichText.media_ids(value) == [id]

    refute RichText.valid?(
             doc([%{type: "image", attrs: %{src: "https://other.test/a.jpg"}}]),
             100
           )

    refute RichText.valid?(
             doc([
               %{
                 type: "paragraph",
                 content: [
                   %{
                     type: "text",
                     text: "Click",
                     marks: [%{type: "link", attrs: %{href: "javascript:alert(1)"}}]
                   }
                 ]
               }
             ]),
             100
           )

    refute RichText.valid?("gcf-richtext:{", 100)
  end
end
