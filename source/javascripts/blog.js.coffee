#= require_tree ./vendor

$ ->
  $('pre code').each (i, block) ->
    hljs.highlightBlock block


