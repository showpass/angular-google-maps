angular.module("google-maps").factory "array-sync", ["add-events", (mapEvents) ->
  (mapArray, scope, pathEval) ->
    isSetFromScope = false
    scopePath = scope.$eval(pathEval)
    if !scope.static
      legacyHandlers =
      #listeners / handles to changes of the points from the map direction to update back to our scope (two way)
        set_at: (index) ->
          return if isSetFromScope #important to avoid cyclic forever change loop watch to map event change and back
          value = mapArray.getAt(index)
          return  unless value
          return  if not value.lng or not value.lat
          scopePath[index].latitude = value.lat()
          scopePath[index].longitude = value.lng()

        insert_at: (index) ->
          return if isSetFromScope #important to avoid cyclic forever change loop watch to map event change and back
          value = mapArray.getAt(index)
          return  unless value
          return  if not value.lng or not value.lat

          #check to make sure we are not inserting something that is already there
          scopePath.splice index, 0,
            latitude: value.lat()
            longitude: value.lng()

        remove_at: (index) ->
          return if isSetFromScope #important to avoid cyclic forever change loop watch to map event change and back
          scopePath.splice index, 1

      #Note: we only support display of the outer Polygon ring, not internal holes
      geojsonArray
      if scopePath.type == "Polygon"
        geojsonArray = scopePath.coordinates[0]
      else if scopePath.type == "LineString"
        geojsonArray = scopePath.coordinates

      #TODO: Refactor this is too much copy and paste code that can be in a utility / module
      geojsonHandlers =
        set_at: (index) ->
          return if isSetFromScope #important to avoid cyclic forever change loop watch to map event change and back
          value = mapArray.getAt(index)
          return  unless value
          return  if not value.lng or not value.lat
          geojsonArray[index][1] = value.lat()
          geojsonArray[index][0] = value.lng()

        insert_at: (index) ->
          return if isSetFromScope #important to avoid cyclic forever change loop watch to map event change and back
          value = mapArray.getAt(index)
          return  unless value
          return  if not value.lng or not value.lat
          geojsonArray.splice index, 0, [ value.lng(), value.lat() ]

        remove_at: (index) ->
          return if isSetFromScope #important to avoid cyclic forever change loop watch to map event change and back
          geojsonArray.splice index, 1

      mapArrayListener = mapEvents mapArray,
          if angular.isUndefined scopePath.type then legacyHandlers else geojsonHandlers

    legacyWatcher = (newPath) ->
      isSetFromScope = true
      oldArray = mapArray
      if newPath
        i = 0
        oldLength = oldArray.getLength()
        newLength = newPath.length
        l = Math.min(oldLength, newLength)
        newValue = undefined
        #update existing points if different
        while i < l
          oldValue = oldArray.getAt(i)
          newValue = newPath[i]
          oldArray.setAt i, new google.maps.LatLng(newValue.latitude,
              newValue.longitude)  if (oldValue.lat() isnt newValue.latitude) or (oldValue.lng() isnt newValue.longitude)
          i++
        #add new points
        while i < newLength
          newValue = newPath[i]
          oldArray.push new google.maps.LatLng(newValue.latitude, newValue.longitude)
          i++
        #remove old no longer there
        while i < oldLength
          oldArray.pop()
          i++
      isSetFromScope = false

    geojsonWatcher = (newPath) ->
      isSetFromScope = true
      oldArray = mapArray
      if newPath
        array
        if scopePath.type == "Polygon"
          array = newPath.coordinates[0]
        else if scopePath.type == "LineString"
          array = newPath.coordinates

        i = 0
        oldLength = oldArray.getLength()
        newLength = array.length
        l = Math.min(oldLength, newLength)
        newValue = undefined
        while i < l
          oldValue = oldArray.getAt(i)
          newValue = array[i]
          oldArray.setAt i, new google.maps.LatLng(newValue[1],
              newValue[0])  if (oldValue.lat() isnt newValue[1]) or (oldValue.lng() isnt newValue[0])
          i++
        while i < newLength
          newValue = array[i]
          oldArray.push new google.maps.LatLng(newValue[1], newValue[0])
          i++
        while i < oldLength
          oldArray.pop()
          i++
      isSetFromScope = false

    watchListener =
      if scope.static then scope.$watch else scope.$watchCollection

    ->
      if mapArrayListener #where the heck is this? Dead code?
        mapArrayListener()
        mapArrayListener = null
      if watchListener
        watchListener.apply(scope, [pathEval, if angular.isUndefined(scopePath.type) then legacyWatcher else geojsonWatcher])
        watchListener = null
]