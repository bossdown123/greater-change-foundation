defmodule Gcf.MediaMetadataTest do
  use ExUnit.Case, async: true
  alias Gcf.Admin.MediaMetadata, as: Metadata

  test "capture dates preserve their recorded time and optional offset" do
    assert Metadata.parse_time("2024:02:29 12:13:14", nil) == %{
             local_datetime: "2024-02-29T12:13:14",
             utc_offset_minutes: nil
           }

    assert Metadata.parse_time("2024:02:29 12:13:14", "-05:00") == %{
             local_datetime: "2024-02-29T12:13:14",
             utc_offset_minutes: -300
           }

    assert Metadata.parse_time("2024:02:30 12:13:14", nil) == nil
  end

  test "metadata does not replace missing capture facts with upload times" do
    result = Metadata.normalise(%{"FileModifyDate" => "2025:01:01 00:00:00"})
    assert result.capture == nil
    assert result.coordinates == nil
    assert result.places == %{}
  end

  test "orientation, southern and western GPS coordinates are respected" do
    result =
      Metadata.normalise(%{
        "ImageWidth" => 6000,
        "ImageHeight" => 4000,
        "Orientation" => 6,
        "GPSLatitude" => 18.2,
        "GPSLatitudeRef" => "S",
        "GPSLongitude" => 76.4,
        "GPSLongitudeRef" => "W",
        "City" => "Kingston"
      })

    assert result.dimensions == %{width: 4000, height: 6000}
    assert result.coordinates.latitude == -18.2
    assert result.coordinates.longitude == -76.4
    assert result.places == %{"city" => "Kingston"}
  end
end
