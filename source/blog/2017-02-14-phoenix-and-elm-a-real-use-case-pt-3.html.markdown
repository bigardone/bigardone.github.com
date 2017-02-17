---
title: Phoenix and Elm, a real use case (pt. 3)
date: 2017-02-14 22:26 PST
tags: elixir, phoenix, elm, ecto, postgresql
except: Adding full text search and pagination to the contact list
published: false
---


<div class="index">
  <p>This post belongs to the <strong>Phoenix and Elm, a real use case</strong> series.</p>
  <ol>
    <li><a href="/blog/2017/02/02/phoenix-and-elm-a-real-use-case-pt-1/">Introduction to creating a SPA with Phoenix and Elm</a></li>
    <li><a href="/blog/2017/02/08/phoenix-and-elm-a-real-use-case-pt-2/">Rendering the initial contact list</a></li>
    <li><a href="/blog/2017/02/14/phoenix-and-elm-a-real-use-case-pt-3/">Adding full text search and pagination to the contact list</a></li>
    <li>Coming soon...</li>
  </ol>

  <a href="https://phoenix-and-elm.herokuapp.com/" target="_blank"><i class="fa fa-cloud"></i> Live demo</a> |
  <a href="https://github.com/bigardone/phoenix-and-elm" target="_blank"><i class="fa fa-github"></i> Source code</a>
</div>

## Full text search and pagination

In the previous part we managed to render the first page of the contact list. Recalling what we have done so far, we are using
scrivener to paginate de list, and it does it using the request params, concretely `page` and `page_size`. Today we are going to cover how
to render the pagination buttons, send a page request when the user click on any of them, and adding a search box so the user can
search contacts by any of their fields, which involves creating a full text search index in the table using Ecto. Let's get cracking!

### The Pagination buttons

Before continuing, let's change the `brunch-config.js` file and add the debugging option to `elmBrunch` plugin:

```javascript
exports.config = {
  // ...

  plugins: {
    // ...

    elmBrunch: {
      // ...

      makeParameters: ['--debug'],
    },
  }

  // ...
}
```

This option is very convenient while we are developing Elm, since it adds a div at the bottom right corner of the page where you can see the current
state of the application and navigate through all the different updates.


<img src="/images/blog/phoenix_and_elm/elm-debug.jpg" alt="Elm history" style="background: #fff;" />

If we take a closer look to the current state (Model) after the application renders, we already have everythig we need for rendering the pagination links:

```elm
{ contactList =
    { entries = List(9)
    , page_number = 1
    , total_entries = 100
    , total_pages = 12
    }
, error = Nothing
}
```

Let's add the pagination list to the `ContactList.View` module:


```elm
-- web/elm/ContactList/View.elm

module ContactList.View exposing (indexView)

-- ...


indexView : Model -> Html Msg
indexView model =
    div
        [ id "home_index" ]
        [ paginationList model.contactList.total_pages model.contactList.page_number
        , div
            []
            [ contactsList model ]
        , paginationList model.contactList.total_pages model.contactList.page_number
        ]

-- ...


paginationList : Int -> Int -> Html Msg
paginationList totalPages pageNumber =
    List.range 1 totalPages
        |> List.map (paginationLink pageNumber)
        |> ul [ class "pagination" ]


paginationLink : Int -> Int -> Html Msg
paginationLink currentPage page =
    let
        classes =
            classList [ ( "active", currentPage == page ) ]
    in
        li
            []
            [ a
                [ classes ]
                []
            ]

```


After saving the file and refreshing the browser, the page should look like this:


<img src="/images/blog/phoenix_and_elm/pagination.jpg" alt="Pagination links" style="background: #fff;" />

Now that we have the links, we have to make them clickable, and fetch the correponding page once clicked. For that
we have to create a new message and the corresponding handle in the update function. Let's start by adding the
new message to the `Messages` module:

```elm
-- web/elm/Messages.elm

module Messages exposing (..)

import Http
import Model exposing (ContactList)


type Msg
    = FetchResult (Result Http.Error ContactList)
    | Paginate Int
```

Adding the `Paginate Int` type will make the compiler complain, as the update module doesn't handle it, so let's fix that:

```elm
-- web/elm/Update.elm

module Update exposing (..)

import Commands exposing (fetch)
import Messages exposing (..)
import Model exposing (..)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- ...

        Paginate pageNumber ->
            model ! [ fetch pageNumber ]
```

We are calling the same `fetch` function from the `Commands` module that is called from the `init` function one the applications loads.
Now we need to pass the page we want to request, so let's update it:

```elm
-- web/elm/Commands.elm


module Commands exposing (..)

import Decoders exposing (contactListDecoder)
import Http
import Messages exposing (Msg(..))


fetch : Int -> Cmd Msg
fetch page =
    let
        apiUrl =
            "/api/contacts?page=" ++ (toString page)

        request =
            Http.get apiUrl contactListDecoder
    in
        Http.send FetchResult request
```

If we check the compiler output we can see that there is still once thing more to change:

```bash
-- TYPE MISMATCH ------------------------------------------------------ Main.elm

The right side of (!) is causing a type mismatch.

13|     initialModel ! [ fetch ]
                       ^^^^^^^^^
(!) is expecting the right side to be a:

    List (Cmd Msg)

But the right side is:

    List (Int -> Cmd Msg)

Hint: It looks like a function needs 1 more argument.
```

The fix is very simple, so let's update the `init` function in the `Main` module:

```elm
-- web/elm/Main.elm

module Main exposing (..)


init : ( Model, Cmd Msg )
init =
    initialModel ! [ fetch 1 ]
```

Finally we need to add the `onClick` handler to the page link:


```elm
-- web/elm/ContactList/View.elm

module ContactList.View exposing (indexView)
import Html.Events exposing (..)

-- ...


paginationLink : Int -> Int -> Html Msg
paginationLink currentPage page =
    let
        classes =
            classList [ ( "active", currentPage == page ) ]
    in
        li
            []
            [ a
                [ classes
                , onClick <| Paginate page
                ]
                []
            ]

```

If we refresh the browser and click on any of the buttons, it will render the corresponding page of contacts, yay!

### Full text search

Now that users can navigate through the contact list pages, let's make it easier for them to filter contacts by
adding a search box. We want to filter by any of the users table fields, so let's start by creating a full text index
to the users table using an Ecto migration:

```bash
$ mix ecto.gen.migration create_gin_index_for_contacts
```

We need to edit the migration file manually to add the index:

```ruby
# priv/repo/migrations/20160817151844_create_gin_index_for_contacts.exs

defmodule PhoenixAndElm.Repo.Migrations.CreateGinIndexForContacts do
  use Ecto.Migration

  def change do
    execute """
      CREATE INDEX contacts_full_text_index
      ON contacts
      USING gin (
        to_tsvector(
          'english',
          first_name || ' ' ||
          last_name || ' ' ||
          location || ' ' ||
          headline || ' ' ||
          email || ' ' ||
          phone_number
        )
      );
    """
  end
end
```

And run it:

```bash
$ mix exto.migrate
```

Next step is adding a helper function to the `Contact` model module, to build the query:

```elixit
# web/models/contact.ex

defmodule PhoenixAndElm.Contact do
  # ...

  def search(query, ""), do: query
  def search(query, search_query) do
    search_query = ts_query_format(search_query)

    query
    |> where(
      fragment(
      """
      (to_tsvector(
        'english',
        coalesce(first_name, '') || ' ' ||
        coalesce(last_name, '') || ' ' ||
        coalesce(location, '') || ' ' ||
        coalesce(headline, '') || ' ' ||
        coalesce(email, '') || ' ' ||
        coalesce(phone_number, '')
      ) @@ to_tsquery('english', ?))
      """,
      ^search_query
      )
    )
  end

  defp ts_query_format(search_query) do
    search_query
    |> String.trim
    |> String.split(" ")
    |> Enum.map(&("#{&1}:*"))
    |> Enum.join(" & ")
  end
end
```

The `search` function creates a query using a fragment with the ts_vector function from Postgres to search by any of the
columns in the table. As full text search is quite an extensive topic, I'm not going to write any more about its details, but
you can learn more about it in the official documentation.

In order to use the new `search` function we have just created, we need to chage the ContactController:

```ruby
# web/controllers/contact_controller.ex

defmodule PhoenixAndElm.ContactController do
  use PhoenixAndElm.Web, :controller

  alias PhoenixAndElm.Contact

  def index(conn, params) do
    search = Map.get(params, "search", "")

    page = Contact
      |> Contact.search(search)
      |> order_by(:first_name)
      |> Repo.paginate(params)

    render conn, page: page
  end
end
```

We are getting the search key from the params (or an empty string if it does not exist), and calling the Contact.search with it. As the search function returns
a query, we can concatenate more queries to it, like `order_by`, before getting the result page.

### The search input

Now that our backend is ready to receive a `search` param and make a full text search in the contacts table, let's start by adding
the search string to the Elm model:

```elm
-- web/elm/Model.elm


module Model exposing (..)


type alias Model =
    { contactList : ContactList
    , error : Maybe String
    , search : String
    }

-- ...


initialModel : Model
initialModel =
    { contactList = initialContatcList
    , error = Nothing
    , search = ""
    }
```

Let's continue by adding the search input to the `ContactList.View` module:

```elm
-- web/elm/ContactList/View.elm

module ContactList.View exposing (indexView)

-- ...

indexView : Model -> Html Msg
indexView model =
    div
        [ id "home_index" ]
        [ searchSection model
        , paginationList model.contactList.total_pages model.contactList.page_number
        , div
            []
            [ contactsList model ]
        , paginationList model.contactList.total_pages model.contactList.page_number
        ]


searchSection : Model -> Html Msg
searchSection model =
    let
        totalEntries =
            model.contactList.total_entries

        contactWord =
            if totalEntries == 1 then
                "contact"
            else
                "contacts"

        headerText =
            if totalEntries == 0 then
                ""
            else
                (toString totalEntries) ++ " " ++ contactWord ++ " found"
    in
        div
            [ class "filter-wrapper" ]
            [ div
                [ class "overview-wrapper" ]
                [ h3
                    []
                    [ text headerText ]
                ]
            , div
                [ class "form-wrapper" ]
                [ Html.form
                    [ ]
                    [ input
                        [ type_ "search"
                        , placeholder "Search contacts..."
                        , value model.search
                        ]
                        []
                    ]
                ]
            ]

```

Using the total_entries from the model, we generate the header text to display the number of occurrences found
(or an empty text if there is no matches) and we also add a Html search input. After saving the file and
refreshing the browser, we should see the following:


<img src="/images/blog/phoenix_and_elm/search.jpg" alt="Search" style="background: #fff;" />


So far, so good. We have set the value of the `model.search` as the value of the search input. Therefore, we need to
update the model every time the user types on it. To achieve this, let's first add the corresponding event handler
to the input:


```elm
-- web/elm/ContactList/View.elm

module ContactList.View exposing (indexView)

-- ...


searchSection : Model -> Html Msg
searchSection model =
    let
        -- ...
    in
        -- ...

            [ input
                [ type_ "search"
                , placeholder "Search contacts..."
                , value model.search
                , onInput HandleSearchInput
                ]
                []
            ]

        -- ...
```

Next we have to add the `HandleSearchInput` message to the `Messages` module:

```elm
-- web/elm/Messages.elm

module Messages exposing (..)

-- ...

type Msg
    = FetchResult (Result Http.Error ContactList)
    | Paginate Int
    | HandleSearchInput String
```

And don't forget about the corresponding handle in the `Update` module, otherwise the compiler will complain:

```elm
-- web/elm/Update.elm

module Update exposing (..)

-- ...

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- ...

        HandleSearchInput value ->
            { model | search = value } ! []

```

After these changes compile, go to the seach input and type some text, keeping an eye on the Elm's history debugger to check
how the model gets updated on each key stroke:


<img src="/images/blog/phoenix_and_elm/oninput.jpg" alt="On input" style="background: #fff;" />

There is only one thing left to make the search work, which is sending the model's search value while fetching the contacts.
For that let's add another event handler, this time to the form so we can trigger the search when the user hits the intro key:


```elm
-- web/elm/ContactList/View.elm

module ContactList.View exposing (indexView)

-- ...


searchSection : Model -> Html Msg
searchSection model =
    let
        -- ...
    in
        -- ...
        , div
            [ class "form-wrapper" ]
            [ Html.form
                [ onSubmit HandleFormSubmit ]

                -- ...
```

We need again to add the `HandleFormSubmit` message:

```elm
-- web/elm/Messages.elm

module Messages exposing (..)

-- ...

type Msg
    = FetchResult (Result Http.Error ContactList)
    | Paginate Int
    | HandleSearchInput String
    | HandleFormSubmit

```

Handling this message in the `Update` module implies doing some refactor to some of the code we already have.
The reason is that we want to send both the page and the search while fetching, so let's start by editing the
`Update`:

```elm
-- web/elm/Update.elm

module Update exposing (..)

-- ...

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- ...

        Paginate pageNumber ->
            model ! [ fetch pageNumber model.search ]

        -- ...

        HandleFormSubmit ->
            model ! [ fetch 1 model.search ]


```

In the `Paginate` case, we want to fetch the corresponding page for the current search value. On the other hand, in the
`HandleFormSubmit`, we always want to request the first page when the user is doing a new search. The next edit we need to
make is adding the `search` as a param of the `fetch` function, so let's edit the `Commands` module:

```elm
-- web/elm/Commands.elm

module Commands exposing (..)

-- ...

fetch : Int -> String -> Cmd Msg
fetch page search =
    let
        apiUrl =
            "/api/contacts?page=" ++ (toString page) ++ "&search=" ++ search

        request =
            Http.get apiUrl contactListDecoder
    in
        Http.send FetchResult request


```

The compiler still complains about one more thing, which is the call to `fetch` in the init function of the `Main` module,
so let's fix it:

```elm
-- web/elm/Main.elm

module Main exposing (..)

-- ...

init : ( Model, Cmd Msg )
init =
    initialModel ! [ fetch 1 "" ]

-- ...
```

And that's it! After refreshing the browser, type anything in the search input, press intro, and you shall see the filtered list of
contacts:


<img src="/images/blog/phoenix_and_elm/search-results.jpg" alt="Search results" style="background: #fff;" />
