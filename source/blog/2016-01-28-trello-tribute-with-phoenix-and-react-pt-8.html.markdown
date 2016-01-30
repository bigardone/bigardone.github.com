---
title: Trello tribute with Phoenix and React (pt.8)
date: 2016-01-28 01:56 PST
tags: elixir, phoenix, react, redux
canonical: https://blog.diacode.com/trello-clone-with-phoenix-and-react-pt-8
published: false
excerpt:
  Creating boards and inviting adding users as board members
---
<div class="index">
  <p>This post belongs to the <strong>Trello tribute with Phoenix Framework and React</strong> series.</p>
  <ol>
    <li><a href="/blog/2016/01/04/trello-tribute-with-phoenix-and-react-pt-1">Intro and selected stack</a></li>
    <li><a href="/blog/2016/01/11/trello-tribute-with-phoenix-and-react-pt-2">Phoenix Framework project setup</a></li>
    <li><a href="/blog/2016/01/12/trello-tribute-with-phoenix-and-react-pt-3">The User model and JWT auth</a></li>
    <li><a href="/blog/2016/01/14/trello-tribute-with-phoenix-and-react-pt-4/">Front-end for sign up with React and Redux</a></li>
    <li><a href="/blog/2016/01/18/trello-tribute-with-phoenix-and-react-pt-5/">Database seeding and sign in controller</a></li>
    <li><a href="/blog/2016/01/20/trello-tribute-with-phoenix-and-react-pt-6/">Front-end authentication with React and Redux</a></li>
    <li><a href="/blog/2016/01/25/trello-tribute-with-phoenix-and-react-pt-7/">Sockets and channels</a></li>
    <li>Coming soon</li>
  </ol>

  <a href="https://phoenix-trello.herokuapp.com/"><i class="fa fa-cloud"></i> Live demo</a> |
  <a href="https://github.com/bigardone/phoenix-trello"><i class="fa fa-github"></i> Source code</a>
</div>

## Boards and board members
Now that we have covered the important aspects of user registration and authentication
management as well as connecting to the socket and joining channels, we are ready
to move on to the next level and let the user create his own boards and invite other
existing users to join them.

### The Board migration
First we need to create the migration and model. To so just run:

```
$ mix phoenix.gen.model Board boards board_id:references:board name:string

```

This will generate our new migration file which will look something similar to this:

```elixir
# priv/repo/migrations/20151224093233_create_board.exs

defmodule PhoenixTrello.Repo.Migrations.CreateBoard do
  use Ecto.Migration

  def change do
    create table(:boards) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps
    end

    create index(:boards, [:user_id])
  end
end

```

The new table called `boards` will have, apart from its `id` and `timestamps` fields,
a `name` field and a foreign key to the `users` table. Note that
we are relying on the database to delete as well the boards belonging to a user if the user
is deleted. It also adds an index to the `user_id` to speed up things, and a
`null` constraints to the `name`.

Having finished modifying the migration file, we need to run it:

```
$ mix ecto.migrate
```

### The Board model
Let's take a look to the `Board` model:


```elixir
# web/models/board.ex

defmodule PhoenixTrello.Board do
  use PhoenixTrello.Web, :model

  alias __MODULE__

  @derive {Poison.Encoder, only: [:id, :name, :user]}

  schema "boards" do
    field :name, :string
    belongs_to :user, User

    timestamps
  end

  @required_fields ~w(name user_id)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields))
  end
end
```

For now there's nothing important to mention yet, but we need to update
the `User` model to add its related owned boards:

```elixir
# web/models/user.ex

defmodule PhoenixTrello.User do
  use PhoenixTrello.Web, :model

  # ...

  schema "users" do
    # ...

    has_many :owned_boards, PhoenixTrello.Board

    # ...
  end

  # ...
end
```

Why `owned_boards`? To differentiate between the boards a user creates and the ones
he's added by other users, but lets don't worry about this right now as see will dive into
it more deeply later on.

### The BoardController
So to create new boards we are going to need to update the routes file

```elixir
# web/controllers/board_controller.ex

defmodule PhoenixTrello.BoardController do
  use PhoenixTrello.Web, :controller

  plug Guardian.Plug.EnsureAuthenticated, handler: PhoenixTrello.SessionController

  alias PhoenixTrello.{Repo, Board}

  def index(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)

    owned_boards = current_user
      |> assoc(:owned_boards)
      |> Board.preload_all
      |> Repo.all

    render(conn, "index.json", owned_boards: owned_boards)
  end
end

```
