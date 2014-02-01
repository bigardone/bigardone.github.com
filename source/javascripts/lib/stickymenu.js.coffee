do ($ = jQuery, window, document) ->
  pluginName = "stickyMenu"
  defaults = {}

  class Plugin
    constructor: (@element, options) ->
      @settings = $.extend {}, defaults, options
      @_defaults = defaults
      @_name = pluginName
      @init()

    init: ->
      @$el = $(@element)
      @$toggle = @$el.find '.toggle-nav'
      @$nav = @$el.find('.nav-links')
      @settings.offset = $("#main_content").offset().top
      @scrolling = false
      @listen()

    listen: =>
      @$toggle.on 'click', @toggleMenu
      @$nav.find('a').on 'click', @scrollTo
      $(window).on "scroll", @manageScroll

    manageScroll: ()=>
      unless @scrolling
        y = $(document).scrollTop()
        @$nav.find('a').each (i, el) =>
          link = $(el)
          target = $(link.attr 'href')
          top = target.offset().top
          height = target.height()

          if y >= top and y <= (top + height)
            @activateLink link

    toggleMenu: (e)=>
      e.preventDefault()
      @$nav.stop().toggleClass 'show', 300

    scrollTo: (e)=>
      e.preventDefault()
      link = $(e.target)
      target = $(link.attr 'href')

      if target.length
        @scrolling = true

        $("html,body").animate
          scrollTop: target.offset().top
        , 600
        , ()=>
          @activateLink(link)

    activateLink: (link)=>
      link.stop().closest('li').addClass('active').siblings('.active').removeClass 'active'
      @scrolling = false



  $.fn[pluginName] = (options) ->
    @each ->
      if !$.data(@, "plugin_#{pluginName}")
        $.data(@, "plugin_#{pluginName}", new Plugin(@, options))
