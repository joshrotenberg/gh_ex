defmodule GhEx.CodeSecurity do
  @moduledoc """
  Repository code-scanning, Dependabot, and secret-scanning alerts.

  These thin wrappers return the same `{:ok, body, meta}` /
  `{:error, reason}` shape as `GhEx.REST`; `opts` pass through to `Req`.

  The authenticated token needs the corresponding repository alert permission.
  The security feature must also be available and enabled for the repository.
  Updating a code-scanning alert requires write permission.
  """

  alias GhEx.{Client, REST}

  @type alert_number :: non_neg_integer() | String.t()

  @doc "Lists code-scanning alerts for a repository."
  @spec list_alerts(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_alerts(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/code-scanning/alerts", opts)
  end

  @doc "Auto-paginates repository code-scanning alerts into a lazy `Stream`."
  @spec stream_alerts(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_alerts(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/code-scanning/alerts", opts)
  end

  @doc "Gets a code-scanning alert by number."
  @spec get_alert(Client.t(), String.t(), String.t(), alert_number(), keyword()) :: REST.result()
  def get_alert(client, owner, repo, alert_number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/code-scanning/alerts/#{alert_number}", opts)
  end

  @doc "Updates a code-scanning alert."
  @spec update_alert(Client.t(), String.t(), String.t(), alert_number(), map(), keyword()) ::
          REST.result()
  def update_alert(client, owner, repo, alert_number, attrs, opts \\ []) do
    REST.patch(
      client,
      "/repos/#{owner}/#{repo}/code-scanning/alerts/#{alert_number}",
      Keyword.put(opts, :json, attrs)
    )
  end

  @doc "Lists Dependabot alerts for a repository."
  @spec list_dependabot_alerts(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_dependabot_alerts(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/dependabot/alerts", opts)
  end

  @doc "Auto-paginates repository Dependabot alerts into a lazy `Stream`."
  @spec stream_dependabot_alerts(Client.t(), String.t(), String.t(), keyword()) ::
          Enumerable.t()
  def stream_dependabot_alerts(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/dependabot/alerts", opts)
  end

  @doc "Gets a Dependabot alert by number."
  @spec get_dependabot_alert(Client.t(), String.t(), String.t(), alert_number(), keyword()) ::
          REST.result()
  def get_dependabot_alert(client, owner, repo, alert_number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/dependabot/alerts/#{alert_number}", opts)
  end

  @doc "Lists secret-scanning alerts for a repository."
  @spec list_secret_alerts(Client.t(), String.t(), String.t(), keyword()) :: REST.result()
  def list_secret_alerts(client, owner, repo, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/secret-scanning/alerts", opts)
  end

  @doc "Auto-paginates repository secret-scanning alerts into a lazy `Stream`."
  @spec stream_secret_alerts(Client.t(), String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_secret_alerts(client, owner, repo, opts \\ []) do
    REST.stream(client, "/repos/#{owner}/#{repo}/secret-scanning/alerts", opts)
  end

  @doc "Gets a secret-scanning alert by number."
  @spec get_secret_alert(Client.t(), String.t(), String.t(), alert_number(), keyword()) ::
          REST.result()
  def get_secret_alert(client, owner, repo, alert_number, opts \\ []) do
    REST.get(client, "/repos/#{owner}/#{repo}/secret-scanning/alerts/#{alert_number}", opts)
  end
end
