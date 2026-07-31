# Stacked pull requests

GitHub's stacked pull requests are in public preview. The feature and its merge
queue integration are rolling out progressively, so a repository where stacks
are not yet enabled returns `404` from the stacks and asynchronous merge APIs.

gh_ex keeps stack resources as raw maps, like its other REST resources. A pull
request returned by `GhEx.PullRequests.list/4` or `get/5` has a `"stack"` object
when it belongs to a stack, and `nil` otherwise.

## Create and manage stacks

`GhEx.Stacks` wraps the dedicated REST endpoints. Pull request numbers are
always ordered from the bottom of the stack to the top:

```elixir
{:ok, stack, _meta} =
  GhEx.Stacks.create(client, "o", "r", %{
    pull_requests: [101, 102, 103]
  })

stack_number = stack["number"]

{:ok, updated, _meta} =
  GhEx.Stacks.add(client, "o", "r", stack_number, %{
    pull_requests: [104]
  })

# Find the stack containing a pull request.
{:ok, [stack], _meta} =
  GhEx.Stacks.list(client, "o", "r", params: [pull_request: 102])

# Removes unmerged entries. A fully dissolved stack returns 204.
GhEx.Stacks.unstack(client, "o", "r", stack_number)
```

The pull requests must already form a branch chain: the bottom pull request
targets the stack base, and each later pull request targets the branch directly
below it.

## Merge a stack

The legacy synchronous `GhEx.PullRequests.merge/6` cannot merge a stacked pull
request. Submit the asynchronous merge, then poll its UUID:

```elixir
{:ok, %{"status" => "pending", "details" => %{"uuid" => uuid}}, _meta} =
  GhEx.PullRequests.merge_async(client, "o", "r", 103, %{
    merge_method: "squash",
    merge_action: "default"
  })

{:ok, result, _meta} =
  GhEx.PullRequests.get_merge_result(client, "o", "r", 103, uuid)

case result["status"] do
  "pending" -> :poll_again
  "merged" -> {:merged, result["details"]["sha"]}
  "enqueued" -> :merge_queue
  "failed" -> {:error, result["details"]["message"]}
end
```

Selecting a pull request merges it and every unmerged pull request below it.
The direct merge is atomic. With `merge_action: "default"`, GitHub selects a
direct merge or the base branch's merge queue as appropriate.

If the submit endpoint returns `409`, another request is already pending. gh_ex
normalizes that non-2xx response into `{:error, %GhEx.Error{}}`; the existing
pending result and UUID are preserved in `error.body`.

## GraphQL and webhooks

No GraphQL-specific wrapper is needed because `GhEx.GraphQL` accepts arbitrary
queries. GitHub exposes read-only `stack` and `stackEntry` fields on
`PullRequest`:

```elixir
GhEx.GraphQL.query(
  client,
  """
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        number
        stackEntry { position }
        stack {
          number
          size
          baseRefName
          entries(first: 100) {
            nodes { position pullRequest { number title state } }
          }
        }
      }
    }
  }
  """,
  owner: "o",
  repo: "r",
  number: 102
)
```

For webhooks, a stacked pull request includes
`payload["pull_request"]["stack"]`. GitHub also sends a `pull_request` event
with action `"stacked"` when a pull request joins a stack. The `opened` event
does not contain stack metadata because GitHub creates the pull request before
adding it to the stack.

See GitHub's [REST API](https://github.github.com/gh-stack/reference/rest-api/),
[Merge API](https://github.github.com/gh-stack/reference/merge-api/),
[GraphQL API](https://github.github.com/gh-stack/reference/graphql-api/), and
[webhook](https://github.github.com/gh-stack/reference/webhooks/) references for
the complete preview contract.
