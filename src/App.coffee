###

This app creates a column chart that shows the number of new Defects that were created for each month
over the last year and the number that were closed. It also creates a trend chart that shows the total number of
open Defects for each day.

###

Ext.define('CustomApp',

    extend: 'Rally.app.App'
    componentCls: 'app'
    launch: ->
      @createColumnChart()
      @createTrendChart()
    

    getColumnFilters: ->

      ###
      Returns a filter that defines the type of the artifacts we're
      looking for, and the state they need to be in, to be displayed
      in the column chart. 
      ###


      ProjectOid = this.getContext().getProject().ObjectID;


      projectFilter = Ext.create('Rally.data.lookback.QueryFilter',
          property: '_ProjectHierarchy'
          operator: '='
          value: ProjectOid
        )

      typeFilter = Ext.create('Rally.data.lookback.QueryFilter', 
          property: '_TypeHierarchy'
          operator: '='
          value: 'Defect'
        )


      ###
      stateFilters filters for snapshots that have either 'Idea' as their scheduleState
      or have a ScheduleState greater than 'Accepted' and previous ScheduleStates
      less than 'Accepted'
      ###
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

      return projectFilter.and(typeFilter.and(stateFilters))
      #return typeFilter.and(stateFilters)

    createColumnCalculator: ->

      ###
      This function defines the calculator that is used for the 
      column chart. It takes the snapshots given to it (see the
      getColumnFilters function) and returns series data for the
      chart. 

      constructor() is necessary for the calculator to work

      prepareChartData() gets all the snapshots from the given store.

      runCalculation() is the function that does most of the work.
        * It first groups all the snapshots by their ObjectID (See LoDash's _.groupBy function)
        * For each list of snapshots by ObjectID, it takes the first (being the snapshot of the artifact when it was first created) and puts it into the
          openedSnapshots array. takes the snapshot of when the artifact was closed (if it exists) and
          puts it in the closedSnapshots array. 
        * The getMonth function takes an ISO 8601 date, converts it into Ext's Date format, and then returns the
          month as a string from 01 to 12.
        * Then it passes the opened and closed snapshot arrays (grouped by month) into the xAxisDataTransformer function.
        * Finally, it creates the chartData object which tells the chart what to graph, and returns it.

      xAxisDataTransformer() is given an array of key-value objects,
      with each key a month, and each value a list of the snapshots that
      fall under that month. It then returns an array of the number of snapshots
      per month.


      ###


      Ext.define 'My.ColumnCalculator',
        extend: 'Rally.data.lookback.calculator.BaseCalculator'
        mixins: { observable : "Ext.util.Observable" }


        constructor: ->
          @mixins.observable.constructor.call @
          @callParent arguments
          return

        prepareChartData: (store) ->
          snapshots = store.data.items
          @runCalculation snapshots

        runCalculation: (snapshots) ->

          groupedSnapshots = _.groupBy snapshots, (snapshot) -> snapshot.data.ObjectID

          openedSnapshots = []
          closedSnapshots = []

          _.each groupedSnapshots, (snapshots, oid) ->
            openedSnapshots.push(snapshots[0])
            if snapshots[snapshots.length - 1].data.State != "Submitted" and snapshots.length != 1
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
                  name: 'New Defects'
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

        xAxisDataTransformer: (snapshotsByMonth) ->
          data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
          _.each(snapshotsByMonth, (snapshots, month) ->
            data[month - 1] = snapshots.length
          )
          data

    createColumnChart: ->

      ###
      This function creates and displays the chart. The storeConfig is defined below. The filters for the config
      are given by @getColumnFilters and the calculator is created in @createColumnCalculator. The chartConfig
      is mostly aesthetic details.
      ###
      @createColumnCalculator()

      @columnChart = Ext.create('Rally.ui.chart.Chart',
        storeType: 'Rally.data.lookback.SnapshotStore'
        storeConfig:
          hydrate: ["ScheduleState"]
          fetch: ["_ValidFrom", "_ValidTo", "ObjectID", "ScheduleState", "Name"]
          filters: @getColumnFilters()

        calculatorType: 'My.ColumnCalculator'
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


    createTrendChart: ->

      ###
      This function both creates the calculator for the trend chart and the chart itself.
      The chart displays, for every day, the number of open defects, as a zoomable area chart.

      The calculator My.TrendCalc uses the 'count' function to create the data for the chart to display.
      It simply sums the number of opened snapshots per day. More about the functions that the calculator
      supports can be found at: 
        https://developer.help.rallydev.com/apps/2.0rc1/doc/#!/api/Rally.data.lookback.Lumenize.functions

      The rest of the function is the storeConfig and the chartConfig.
      


      ###

      ProjectOid = this.getContext().getProject().ObjectID;

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
            _TypeHierarchy: "Defect"
            ScheduleState: {$lt:"Accepted"}
            _ProjectHierarchy: ProjectOid

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
