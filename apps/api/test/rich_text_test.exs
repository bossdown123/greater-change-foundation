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

  test "figure widths are bounded whole percentages and old figures still work" do
    figure = %{
      type: "gcfFigure",
      attrs: %{mediaId: String.duplicate("a", 32), alt: ""},
      content: []
    }

    assert RichText.valid?(doc([figure]), 100)

    for width <- [1, 40, 100],
        do: assert(RichText.valid?(doc([put_in(figure, [:attrs, :widthPercent], width)]), 100))

    for width <- [0, 101, -1, 40.5, "40"],
        do: refute(RichText.valid?(doc([put_in(figure, [:attrs, :widthPercent], width)]), 100))
  end
end
