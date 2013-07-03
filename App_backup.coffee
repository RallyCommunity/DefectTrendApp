Ext.define('CustomApp',

    extend: 'Rally.app.App'
    componentCls: 'app'
    launch: ->
      @createColumnGrid()
      @createTrendGrid()
    
    createColumnGrid: ->

      Ext.define 'CustomChartCalculator',
        extend: 'Rally.data.lookback.calculator.BaseCalculator'
        mixins: { observable : "Ext.util.Observable" }


        constructor: ->
          @mixins.observable.constructor.call @
          @callParent arguments
          return

        prepareChartData: (store) ->
          snapshots = store.data.items
          @runCalculation snapshots

        xAxisDataTransformer: (snapshotsByMonth) ->
          data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
          _.each(snapshotsByMonth, (snapshots, month) ->
            data[month - 1] = snapshots.length
          )
          data

        runCalculation: (snapshots) ->

          groupedSnapshots = _.groupBy snapshots, (snapshot) -> snapshot.data.ObjectID

          openedSnapshots = []
          closedSnapshots = []

          _.each groupedSnapshots, (snapshots, oid) ->
            openedSnapshots.push(snapshots[0])
            if snapshots[snapshots.length - 1].data.ScheduleState != "Idea" 
              closedSnapshots.push(snapshots[snapshots.length - 1])

          getMonth = (snapshot) -> parseInt(Ext.Date.format(Ext.Date.parse(snapshot.data._ValidFrom, "c"), "m"))

          openedByMonth = _.groupBy openedSnapshots, getMonth

          closedByMonth = _.groupBy closedSnapshots, getMonth

          openxdata = @xAxisDataTransformer openedByMonth
          closedxdata = @xAxisDataTransformer closedByMonth

          chartData = {
            series:
              [
                {
                  name: 'Open Defects'
                  data: openxdata
                },
                {
                  name: 'Closed Defects'
                  data: closedxdata
                }
              ]
            categories: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
          }


          chartData

      typeFilter = Ext.create('Rally.data.lookback.QueryFilter', 
          property: '_TypeHierarchy'
          operator: '='
          value: 'HierarchicalRequirement'
        )

      projectFilter = Ext.create('Rally.data.lookback.QueryFilter',
        property: '_ProjectHierarchy'
        operator: '='
        value: 11985641446
      )

      stateFilters = Rally.data.lookback.QueryFilter.and(
        [
            property: '_PreviousValues.ScheduleState'
            operator: '<'
            value: 'Accepted'
          ,
            property: 'ScheduleState'
            operator: '>='
            value: 'Accepted'
        ]
      ).or({property: 'ScheduleState', operator: '=', value: 'Idea'})
      
      

      allFilters = projectFilter.and(typeFilter.and(stateFilters))


      @columnChart = Ext.create('Rally.ui.chart.Chart',
        storeType: 'Rally.data.lookback.SnapshotStore'
        storeConfig:
          hydrate: ["ScheduleState"]
          fetch: ["_ValidFrom", "_ValidTo", "ObjectID", "ScheduleState", "Name"]
          filters: allFilters

        calculatorType: 'CustomChartCalculator'
        calculatorConfig: {}

        chartConfig:
          chart:
            zoomType: 'x'
            type: 'column'
          title: 
            text: 'Changed Defects over Time'
          xAxis: {}
          yAxis:
            title:
              text: 'Number of Changed Defects'
      )

      @add(@columnChart)


    createTrendGrid: ->

      Ext.define('My.TrendCalc', 
        extend: 'Rally.data.lookback.calculator.TimeSeriesCalculator'

        getMetrics: ->
          [
            as: 'Defects'
            display: 'line'
            f: 'count'
          ]
      )

      @myTrendChart = Ext.create('Rally.ui.chart.Chart', 
        storeType: 'Rally.data.lookback.SnapshotStore'
        storeConfig: 
          find: 
            _TypeHierarchy: "HierarchicalRequirement"
            ScheduleState: {$lt:"Accepted"}
            _ProjectHierarchy: 11985641446

          hydrate: ["Priority"]
          fetch: ["_ValidFrom", "_ValidTo", "ObjectID", "Priority"]

        calculatorType: 'My.TrendCalc'
        calculatorConfig: {}

        chartConfig:
          chart:
            zoomType: 'x'
            type: 'line'
          title: 
            text: 'Defects over Time'
          xAxis: 
            type: 'datetime'
            minTickInterval: 3
          yAxis:
            title:
              text: 'Number of Defects'
      )
      @add(@myTrendChart)


      
)
