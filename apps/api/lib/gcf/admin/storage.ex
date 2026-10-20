defmodule Gcf.Admin.Storage do
  @moduledoc "Private S3-compatible storage. Only the server knows bucket credentials."
  def request(method, key, body \\ "", mime \\ "application/octet-stream") do
    config = Application.get_env(:gcf, :storage, [])
    endpoint = Keyword.get(config, :endpoint, "")
    bucket = Keyword.get(config, :bucket, "gcf-media")

    if endpoint == "" do
      {:error, :storage_unavailable}
    else
      url = String.trim_trailing(endpoint, "/") <> "/" <> bucket <> "/" <> key

      opts = [
        method: method,
        url: url,
        body: body,
        decode_body: false,
        headers: [{"content-type", mime}],
        receive_timeout: 30_000,
        retry: false,
        aws_sigv4: [
          access_key_id: Keyword.get(config, :access_key_id),
          secret_access_key: Keyword.get(config, :secret_access_key),
          region: Keyword.get(config, :region, "garage"),
          service: :s3
        ]
      ]

      case Req.request(opts) do
        {:ok, %{status: status} = result} when status in 200..299 -> {:ok, result.body}
        _ -> {:error, :storage_unavailable}
      end
    end
  end
end
