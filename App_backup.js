(function() {
  Ext.define('CustomApp', {
    extend: 'Rally.app.App',
    componentCls: 'app',
    launch: function() {
      this.createColumnGrid();
      return this.createTrendGrid();
    },
    createColumnGrid: function() {
      var allFilters, projectFilter, stateFilters, typeFilter;
      Ext.define('CustomChartCalculator', {
        extend: 'Rally.data.lookback.calculator.BaseCalculator',
        mixins: {
          observable: "Ext.util.Observable"
        },
        constructor: function() {
          this.mixins.observable.constructor.call(this);
          this.callParent(arguments);
        },
        prepareChartData: function(store) {
          var snapshots;
          snapshots = store.data.items;
          return this.runCalculation(snapshots);
        },
        xAxisDataTransformer: function(snapshotsByMonth) {
          var data;
          data = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
          _.each(snapshotsByMonth, function(snapshots, month) {
            return data[month - 1] = snapshots.length;
          });
          return data;
        },
        runCalculation: function(snapshots) {
          var chartData, closedByMonth, closedSnapshots, closedxdata, getMonth, groupedSnapshots, openedByMonth, openedSnapshots, openxdata;
          groupedSnapshots = _.groupBy(snapshots, function(snapshot) {
            return snapshot.data.ObjectID;
          });
          openedSnapshots = [];
          closedSnapshots = [];
          _.each(groupedSnapshots, function(snapshots, oid) {
            openedSnapshots.push(snapshots[0]);
            if (snapshots[snapshots.length - 1].data.ScheduleState !== "Idea") {
              return closedSnapshots.push(snapshots[snapshots.length - 1]);
            }
          });
          getMonth = function(snapshot) {
            return parseInt(Ext.Date.format(Ext.Date.parse(snapshot.data._ValidFrom, "c"), "m"));
          };
          openedByMonth = _.groupBy(openedSnapshots, getMonth);
          closedByMonth = _.groupBy(closedSnapshots, getMonth);
          openxdata = this.xAxisDataTransformer(openedByMonth);
          closedxdata = this.xAxisDataTransformer(closedByMonth);
          chartData = {
            series: [
              {
                name: 'Open Defects',
                data: openxdata
              }, {
                name: 'Closed Defects',
                data: closedxdata
              }
            ],
            categories: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
          };
          return chartData;
        }
      });
      typeFilter = Ext.create('Rally.data.lookback.QueryFilter', {
        property: '_TypeHierarchy',
        operator: '=',
        value: 'HierarchicalRequirement'
      });
      projectFilter = Ext.create('Rally.data.lookback.QueryFilter', {
        property: '_ProjectHierarchy',
        operator: '=',
        value: 11985641446
      });
      stateFilters = Rally.data.lookback.QueryFilter.and([
        {
          property: '_PreviousValues.ScheduleState',
          operator: '<',
          value: 'Accepted'
        }, {
          property: 'ScheduleState',
          operator: '>=',
          value: 'Accepted'
        }
      ]).or({
        property: 'ScheduleState',
        operator: '=',
        value: 'Idea'
      });
      allFilters = projectFilter.and(typeFilter.and(stateFilters));
      this.columnChart = Ext.create('Rally.ui.chart.Chart', {
        storeType: 'Rally.data.lookback.SnapshotStore',
        storeConfig: {
          hydrate: ["ScheduleState"],
          fetch: ["_ValidFrom", "_ValidTo", "ObjectID", "ScheduleState", "Name"],
          filters: allFilters
        },
        calculatorType: 'CustomChartCalculator',
        calculatorConfig: {},
        chartConfig: {
          chart: {
            zoomType: 'x',
            type: 'column'
          },
          title: {
            text: 'Changed Defects over Time'
          },
          xAxis: {},
          yAxis: {
            title: {
              text: 'Number of Changed Defects'
            }
          }
        }
      });
      return this.add(this.columnChart);
    },
    createTrendGrid: function() {
      Ext.define('My.TrendCalc', {
        extend: 'Rally.data.lookback.calculator.TimeSeriesCalculator',
        getMetrics: function() {
          return [
            {
              as: 'Defects',
              display: 'line',
              f: 'count'
            }
          ];
        }
      });
      this.myTrendChart = Ext.create('Rally.ui.chart.Chart', {
        storeType: 'Rally.data.lookback.SnapshotStore',
        storeConfig: {
          find: {
            _TypeHierarchy: "HierarchicalRequirement",
            ScheduleState: {
              $lt: "Accepted"
            },
            _ProjectHierarchy: 11985641446
          },
          hydrate: ["Priority"],
          fetch: ["_ValidFrom", "_ValidTo", "ObjectID", "Priority"]
        },
        calculatorType: 'My.TrendCalc',
        calculatorConfig: {},
        chartConfig: {
          chart: {
            zoomType: 'x',
            type: 'line'
          },
          title: {
            text: 'Defects over Time'
          },
          xAxis: {
            type: 'datetime',
            minTickInterval: 3
          },
          yAxis: {
            title: {
              text: 'Number of Defects'
            }
          }
        }
      });
      return this.add(this.myTrendChart);
    }
  });

}).call(this);
