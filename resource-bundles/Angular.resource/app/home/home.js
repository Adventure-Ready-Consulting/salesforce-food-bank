'use strict';

/* Controllers for main page */

angular.module('homeController', [
  'appServerData',
  'appServices',
  'mgcrea.ngStrap.dropdown'
]);

angular.module('homeController')
  .controller('homeController', ['$scope', '$location', '$timeout', '$interval', 'fbCheckInList', 'fbHouseholdSearch', 'foundSettings', '$alert', 'jsRemoting', '$window',
  function($scope, $location, $timeout, $interval, fbCheckInList, fbHouseholdSearch, foundSettings, $alert, jsRemoting, $window) {

    $scope.settings = foundSettings;
    $scope.intakes = [];
    $scope.intakeOpen = false;
    $scope.intakeBusy = false;
    $scope.intakeSelected = {};
    $scope.intakeExpanded = {};
    $scope.loadIntakes = function() {
      return jsRemoting.invoke('getPendingIntakes', [], undefined, {timeout: 60000}).then(function(items) {
        $scope.intakes = items || [];
      }, function(reason) { $alert({title:'Unable to load intake approvals',content:reason.message,type:'danger'}); });
    };
    $scope.openIntakes = function() { $scope.intakeOpen = true; $scope.loadIntakes(); };
    $scope.closeIntakes = function() { if (!$scope.intakeBusy) $scope.intakeOpen = false; };
    $scope.selectedIntakeCount = function() {
      return $scope.intakes.filter(function(item) { return !!$scope.intakeSelected[item.id]; }).length;
    };
    $scope.selectAllIntakes = function() {
      $scope.intakes.forEach(function(item) { $scope.intakeSelected[item.id] = true; });
    };
    $scope.decideIntakes = function(items, decision) {
      if ($scope.intakeBusy || !items.length) return;
      if (!$window.confirm((decision === 'Approved' ? 'Approve' : 'Reject') + ' ' + items.length + ' household(s)?')) return;
      $scope.intakeBusy = true;
      var failures = [], completed = 0;
      function next(index) {
        if (index >= items.length) {
          $scope.intakeBusy = false;
          $scope.intakeSelected = {};
          $scope.loadIntakes();
          if (failures.length) $alert({title: completed + ' completed; ' + failures.length + ' failed', content:failures.join('; '), type:'danger'});
          return;
        }
        jsRemoting.invoke('decideIntake', [items[index].id, decision], undefined, {timeout:60000}).then(function() {
          completed++; next(index + 1);
        }, function(err) { failures.push(items[index].name + ': ' + err.message); next(index + 1); });
      }
      next(0);
    };
    $scope.decideSelectedIntakes = function(all) {
      var items = $scope.intakes.filter(function(item) { return all || $scope.intakeSelected[item.id]; });
      $scope.decideIntakes(items, 'Approved');
    };
    $scope.loadIntakes();


    $scope.searchClients = function(query) {
      //var soslRegex = /['!\(\)~\*-]/g;
      //var cleanedQuery = query.replace(soslRegex, '');
      //if (cleanedQuery && cleanedQuery.length >= 2)
      return fbHouseholdSearch.get(query, false);
    };

    $scope.checkIn = function(cid, contactid) {
      if (cid) {
        $location.url('/client/' + cid + '/' + contactid);
      }
    };

    $scope.checkOutAll = function () {
      $location.url('/log_visit_all');
    };    

    $scope.refresh = function() {
      $scope.callingOut = true;
      $scope.loadIntakes();

      fbCheckInList.get().then(
        function(result){
          $scope.checkedInClients = result;
          $timeout(function(){ $scope.callingOut = false; }, 750);
        },
        function(reason){
          $scope.callingOut = false;
          $alert({
            title: 'Failed.',
            content: reason.message,
            type: 'danger'
          });
        }
      );
    };

    $scope.$on('$destroy', function() {
      $interval.cancel(repeater);
    });

    var repeater;
    $scope.refresh();
    repeater = $interval(function() { $scope.refresh(); }, 60000);
  }]);

angular.module('homeController')
  .controller('statsController', ['$scope', '$routeParams', '$cookies', 'fbStats', '$alert',
  function($scope, $routeParams, $cookies, fbStats, $alert) {

    $scope.statsDropdown = [
      { 'text': 'Today', 'click': 'get(\'Today\')' },
      { 'text': 'Yesterday', 'click': 'get(\'Yesterday\')' },
      { 'divider': true },
      { 'text': 'This Week', 'click': 'get(\'This Week\')' },
      { 'text': 'Last Week', 'click': 'get(\'Last Week\')' },
      { 'divider': true },
      { 'text': 'This Month', 'click': 'get(\'This Month\')' },
      { 'text': 'Last Month', 'click': 'get(\'Last Month\')' },
      { 'divider': true },
      { 'text': 'This Year', 'click': 'get(\'This Year\')' },
      { 'text': 'Last Year', 'click': 'get(\'Last Year\')' }
    ];

    // calculate stats for the given timeframe, such as 'Last Week'
    $scope.get = function(tf) {
      $scope.calculating = true;
      $scope.timeframe = tf;
      $scope.timeframeCode = $scope.timeframe.replace(' ', '_').toUpperCase();
      fbStats.get( $scope.timeframeCode ).then(
        function(result){
          $scope.stats = result;
          $scope.calculating = false;
          $cookies.timeframe = $scope.timeframe;
        },
        function(reason){
          $scope.calculating = false;
          $alert({
            title: 'Failed to calculate statistics.',
            content: reason.message,
            type: 'danger'
          });
        }
      );
    };

    // get the last timeframe from a cookie
    $scope.timeframe = $cookies.timeframe;
    if (!$scope.timeframe) {
      $scope.timeframe = 'Today';
    }
    
    $scope.get($scope.timeframe);
  }]);

angular.module('homeController')
  .controller('checkInController', ['$scope', '$window', 'fbCancelCheckIn',
    function($scope, $window, fbCancelCheckIn) {

    $scope.cancelCheckIn = function() {
      if ($window.confirm('Cancel visit for ' + $scope.client.name + '?')) {
        fbCancelCheckIn($scope.client.clientId);
        $scope.$parent.refresh();
      }
    };

  }]);
