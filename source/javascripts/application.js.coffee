#= require_tree ./vendor
#= require_tree ./lib

$ ->

  $('#main_nav').stickyMenu()

  mapCanvas = document.getElementById 'map-canvas'

  mapOptions =
    center: new google.maps.LatLng(43.585284,-5.968088)
    zoom: 15
    mapTypeId: google.maps.MapTypeId.SATELLITE
    disableDefaultUI: true

  map = new google.maps.Map mapCanvas, mapOptions

  $.stellar
    horizontalScrolling: false
    responsive: false


  setTimeout ->
    $('#welcome').removeClass('invisible').addClass "animated fadeInUp"
  , 500




  $(".animate").each ->
    element = $(@)
    animation = element.data 'animation'

    if animation? and element.not('.animated')
      $(window).scroll ->
        top = element.offset().top
        windowTop = $(window).scrollTop()
        element.removeClass('invisible').addClass "animated #{animation}"  if top < windowTop + 800





