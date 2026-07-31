# Resource modules

The convenience modules are thin wrappers over `GhEx.REST` that fill in the
endpoint path. Each function returns the same `{:ok, body, meta}` /
`{:error, reason}` shape as the core and passes `opts` through to `Req` (so
`:params`, headers, and a `Req.Test` plug all work). They cover the
common paths; for anything else, call `GhEx.REST` directly.

On the write wrappers (`create`, `update`, `merge`, and the like), the `attrs`
argument is the sole request body: each sets `:json` to `attrs`, so a `:json`
passed in `opts` is ignored.

The `list_*` functions return a single page. Each has a `stream_*` companion
that auto-paginates into a lazy `Stream` of individual items, following
`Link: rel="next"` (see the [Pagination](pagination.md) guide). The wrapped
endpoints (Search, Actions runs/workflows/jobs, Checks) unwrap their array key
for you.

```elixir
# every open issue, not just the first page
client
|> GhEx.Issues.stream("elixir-lang", "elixir", params: [state: "open", per_page: 100])
|> Stream.map(& &1["number"])
|> Enum.to_list()
```

For a path without a `stream_*` wrapper, call `GhEx.REST.stream/3` directly with
the path and, for an object-wrapped response, the `items:` key.

## Issues

`GhEx.Issues` — list, get, create, update, comment, and add, remove, or replace
labels.

```elixir
GhEx.Issues.list(client, "elixir-lang", "elixir", params: [state: "open"])
GhEx.Issues.create(client, "o", "r", %{title: "Bug", body: "..."})
GhEx.Issues.create_comment(client, "o", "r", 7, "thanks for the report")
GhEx.Issues.add_labels(client, "o", "r", 7, ["bug", "p1"])
GhEx.Issues.remove_label(client, "o", "r", 7, "needs triage")
GhEx.Issues.replace_all_labels(client, "o", "r", 7, ["confirmed", "p1"])
```

## Pull requests

`GhEx.PullRequests` — list, get, create, update, synchronous and asynchronous
merge, raw diff/patch, files, reviews, and line-anchored review comments.
`GhEx.Stacks` — list, get, create, add, and unstack pull request stacks. See the
[Stacked pull requests](stacks.md) guide for the asynchronous merge flow and
GraphQL/webhook fields.

```elixir
GhEx.PullRequests.create(client, "o", "r", %{title: "Fix", head: "fix", base: "main"})
GhEx.PullRequests.list_files(client, "o", "r", 42)
GhEx.PullRequests.get_diff(client, "o", "r", 42)
GhEx.PullRequests.merge(client, "o", "r", 42, %{merge_method: "squash"})
GhEx.PullRequests.create_review(client, "o", "r", 42, %{event: "APPROVE"})
GhEx.Stacks.create(client, "o", "r", %{pull_requests: [41, 42]})
GhEx.PullRequests.merge_async(client, "o", "r", 42, %{merge_action: "default"})

GhEx.PullRequests.create_comment(client, "o", "r", 42, %{
  body: "Please handle nil.", commit_id: sha, path: "lib/a.ex", line: 12, side: "RIGHT"
})
```

## Repositories and contents

`GhEx.Repositories` — get, list (org/user), create, update, delete, commits,
branches. `GhEx.Contents` — read and write files.

```elixir
GhEx.Repositories.get(client, "elixir-lang", "elixir")
GhEx.Repositories.list_for_org(client, "elixir-lang", params: [type: "public"])

{:ok, file, _meta} = GhEx.Contents.get(client, "o", "r", "mix.exs", params: [ref: "main"])

GhEx.Contents.create_or_update_file(client, "o", "r", "NOTES.md", %{
  message: "add notes",
  content: Base.encode64("hello"),
  sha: file["sha"]
})
```

`content` is Base64-encoded, and updating an existing file needs its blob `sha`.

## Commits

`GhEx.Commits` — get a commit, compare refs, find associated pull requests, and
list or create commit comments. Repository-wide listing remains in
`GhEx.Repositories.list_commits/4` and `GhEx.Repositories.stream_commits/4`.

```elixir
GhEx.Commits.get(client, "o", "r", sha)
GhEx.Commits.compare(client, "o", "r", "main", "feature/agent")
GhEx.Commits.list_pulls(client, "o", "r", sha)
GhEx.Commits.create_comment(client, "o", "r", sha, %{body: "Looks good"})
```

## Git references

`GhEx.Git` — get, create, and delete branch or tag references. Read and delete
helpers accept both `heads/name` and fully qualified `refs/heads/name` forms;
create always sends GitHub the required fully qualified form.

```elixir
GhEx.Git.get_ref(client, "o", "r", "heads/main")
GhEx.Git.create_ref(client, "o", "r", %{ref: "heads/release", sha: sha})
GhEx.Git.delete_ref(client, "o", "r", "refs/heads/release")
```

## Releases

`GhEx.Releases` — list, get, get_latest, get_by_tag, create, update, delete.

```elixir
GhEx.Releases.get_latest(client, "o", "r")

GhEx.Releases.create(client, "o", "r", %{
  tag_name: "v1.0.0",
  name: "v1.0.0",
  generate_release_notes: true
})
```

## Actions

`GhEx.Actions` — workflows, runs, jobs, artifacts, logs, dispatch, cancel, and
rerun. A workflow is its numeric id or its file name (`"ci.yml"`). Artifact and
run-log downloads return ZIP bytes; job-log downloads return plain-text bytes.

```elixir
GhEx.Actions.list_workflows(client, "o", "r")
GhEx.Actions.dispatch_workflow(client, "o", "r", "ci.yml", %{ref: "main", inputs: %{env: "prod"}})
GhEx.Actions.list_runs(client, "o", "r", params: [branch: "main", status: "failure"])
GhEx.Actions.rerun(client, "o", "r", run_id)
{:ok, zip_bytes, _meta} = GhEx.Actions.download_artifact(client, "o", "r", artifact_id, "zip")
{:ok, logs, _meta} = GhEx.Actions.download_job_logs(client, "o", "r", job_id)
GhEx.Actions.rerun_failed_jobs(client, "o", "r", run_id)
```

## Activity

`GhEx.Activity` — repository, organization, user, and public event feeds plus
repository starring. Each feed/list has a lazy stream companion. Watching stays
separate from starring and is not part of this module.

```elixir
GhEx.Activity.stream_repo_events(client, "o", "r") |> Enum.take(100)
GhEx.Activity.list_starred(client, "octocat")
{:ok, starred?, _meta} = GhEx.Activity.starred?(client, "o", "r")
GhEx.Activity.star(client, "o", "r")
```

## Checks and statuses

`GhEx.Checks` — check runs. `GhEx.Statuses` — commit statuses.

```elixir
GhEx.Checks.create_run(client, "o", "r", %{name: "lint", head_sha: sha, status: "in_progress"})
GhEx.Checks.list_for_ref(client, "o", "r", sha)

GhEx.Statuses.create(client, "o", "r", sha, %{state: "success", context: "ci/lint"})
GhEx.Statuses.get_combined(client, "o", "r", "main")
```

## Search

`GhEx.Search` — repositories, code, issues_and_pull_requests, users, commits. The
first argument is the `q` query; pass `params:` for `sort` and `order`.

```elixir
GhEx.Search.repositories(client, "tetris language:elixir", params: [sort: "stars"])
GhEx.Search.issues_and_pull_requests(client, "repo:o/r is:open label:bug")
```

## Users, organizations, and teams

`GhEx.Users`, `GhEx.Organizations`, `GhEx.Teams`.

```elixir
GhEx.Users.get_authenticated(client)
GhEx.Users.get(client, "joshrotenberg")
GhEx.Organizations.list_members(client, "elixir-lang")
GhEx.Teams.list(client, "elixir-lang")
```

## Gists

`GhEx.Gists` — list, get, create, update, delete.

```elixir
GhEx.Gists.create(client, %{
  description: "example",
  public: false,
  files: %{"hello.txt" => %{content: "hi"}}
})
```

## Webhooks

`GhEx.Webhooks` is the receiving side: verify a delivery signature and parse the
payload. See the [Testing](testing.md) guide for the full handler pattern.

```elixir
with :ok <- GhEx.Webhooks.verify(body, signature, secret),
     {:ok, payload} <- GhEx.Webhooks.parse(body) do
  handle(event_name, payload)
end
```
