'use strict';

angular.module('logVisitAllController', ['ngRoute']);

angular.module('logVisitAllController')
  .controller('logVisitAllController', [
    '$scope', '$q', '$timeout', '$window', '$location',
    'foundSettings', 'fbCheckInList', 'fbLogVisit', 'fbCustomLabel', '$alert',
    function ($scope, $q, $timeout, $window, $location,
              foundSettings, fbCheckInList, fbLogVisit, fbCustomLabel, $alert) {

      $scope.settings = foundSettings;
      $scope.clients = [];
      $scope.totalWeight = null;
      $scope.logging = false;
      $scope.errorMessage = null;

      $scope.progress = { current: 0, total: 0, name: null };

      // Optional label (matches single visit page)
      $scope.Label_Box_Type = 'Box Type';
      fbCustomLabel.get('Box_Type').then(
        function (result) { $scope.Label_Box_Type = result; },
        function () { /* ignore */ }
      );
      
      // Default boxType if available
      $scope.boxType = null;
      if ($scope.settings && $scope.settings.boxes && $scope.settings.boxes.length) {
        $scope.boxType = $scope.settings.boxes[0].name;
      }

      function loadCheckedIn() {
        fbCheckInList.get().then(
          function (result) {
            // result items have clientId, clientContactId, name, checkInTime, etc.
            $scope.clients = result || [];
          },
          function (reason) {
            $alert({
              title: 'Failed to load current visitors.',
              content: reason && reason.message ? reason.message : 'Unknown error',
              type: 'danger'
            });
          }
        );
      }

      $scope.perClientWeight = function () {
        if (!$scope.clients || !$scope.clients.length) return null;
        if ($scope.totalWeight === null || $scope.totalWeight === undefined) return null;

        var w = parseFloat($scope.totalWeight);
        if (isNaN(w)) return null;

        return w / $scope.clients.length;
      };

      $scope.cancel = function () {
        $location.url('/');
      };

      $scope.recordAllVisits = function () {
        $scope.errorMessage = null;

        if (!$scope.clients || !$scope.clients.length) return;

        var total = parseFloat($scope.totalWeight);
        if (isNaN(total) || total < 0) {
          $scope.errorMessage = 'Please enter a valid total weight (0 or greater).';
          return;
        }

        var per = total / $scope.clients.length;

        $scope.logging = true;
        $scope.progress.total = $scope.clients.length;
        $scope.progress.current = 0;
        $scope.progress.name = null;

        // Run sequentially to avoid hammering remoting / easier error handling
        var chain = $q.when();

        $scope.clients.forEach(function (c) {
          chain = chain.then(function () {
            $scope.progress.current += 1;
            $scope.progress.name = c.name;

            // fbLogVisit(hhid, contactid, boxType, checkoutWeight, pointsUsed, commodities, notes)
            return fbLogVisit(
              c.clientId,
              c.clientContactId,
              $scope.boxType,
              per,
              0,
              {},   // commodities
              ''    // notes
            );
          });
        });

        chain.then(
          function () {
            $scope.logging = false;
            $window.scrollTo(0, 0);
            $alert({ title: 'All visits recorded.', type: 'success', duration: 2 });

            $timeout(function () {
              $location.url('/');
            }, 1500);
          },
          function (reason) {
            $scope.logging = false;
            $scope.errorMessage = (reason && reason.message)
              ? reason.message
              : 'Failed to record one or more visits.';
            $alert({ title: 'Failed.', content: $scope.errorMessage, type: 'danger' });
          }
        );
      };

      // init
      loadCheckedIn();
    }
  ]);