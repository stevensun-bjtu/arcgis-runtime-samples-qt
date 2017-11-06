// [WriteFile Name=GenerateOfflineMap, Category=Maps]
// [Legal]
// Copyright 2017 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// [Legal]

import QtQuick 2.6
import Esri.ArcGISRuntime 100.2
import Esri.ArcGISExtras 1.1
import Esri.ArcGISRuntime.Toolkit.Dialogs 100.2

Rectangle {
    id: rootRectangle
    clip: true
    width: 800
    height: 600

    property real scaleFactor: System.displayScaleFactor
    property url outputMapPackage: System.temporaryFolder.url + "/OfflineMap_%1.mmpk".arg(new Date().getTime().toString())
    property string webMapId: "acc027394bc84c2fb04d1ed317aac674"

    MapView {
        id: mapView
        anchors.fill: parent

        // Create a Map from a Portal Item
        Map {
            id: map

            PortalItem {
                id: mapPortalItem

                itemId: webMapId
                Portal {
                    loginRequired: true
                }
            }
        }

        // Create a button and anchor it to the attribution top
        DownloadButton {
            id: downloadButton
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: mapView.attributionTop
                margins: 5 * scaleFactor
            }
            visible: map.loadStatus === Enums.LoadStatusLoaded

            onButtonClicked: extentRectangle.getRectangleEnvelope();
        }
    }

    // Create an extent rectangle for selecting the offline area
    Rectangle {
        id: extentRectangle
        anchors.centerIn: parent
        width: parent.width - (50 * scaleFactor)
        height: parent.height - (125 * scaleFactor)
        color: "transparent"
        visible: map.loadStatus === Enums.LoadStatusLoaded
        border {
            color: "red"
            width: 3 * scaleFactor
        }

        function getRectangleEnvelope() {
            var corner1 = mapView.screenToLocation(extentRectangle.x, extentRectangle.y);
            var corner2 = mapView.screenToLocation((extentRectangle.x + extentRectangle.width), (extentRectangle.y + extentRectangle.height));
            var envBuilder = ArcGISRuntimeEnvironment.createObject("EnvelopeBuilder");
            envBuilder.setCorners(corner1, corner2);
            var mapExtent = GeometryEngine.project(envBuilder.geometry, SpatialReference.createWebMercator());
            offlineMapTask.createDefaultGenerateOfflineMapParameters(mapExtent);
        }
    }


    // Create Offline Map Task
    OfflineMapTask {
        id: offlineMapTask
        portalItem: mapPortalItem
        property var generateJob

        onErrorChanged: console.log("error:", error.message, error.additionalMessage);

        onCreateDefaultGenerateOfflineMapParametersStatusChanged: {
            if (createDefaultGenerateOfflineMapParametersStatus !== Enums.TaskStatusCompleted)
                return;

            // Take the map offline once the parameters are generated
            takeMapOffline(offlineMapTask.createDefaultGenerateOfflineMapParametersResult);
        }


        function takeMapOffline(parameters) {
            // create the job
            generateJob = offlineMapTask.generateOfflineMap(parameters, outputMapPackage);

            // check if job is valid
            if (generateJob) {
                // show the export window
                generateWindow.visible = true;

                // connect to the job's status changed signal to know once it is done
                generateJob.jobStatusChanged.connect(updateJobStatus);
                // connect to the job's progress changed signal
                generateJob.progressChanged.connect(updateProgress);

                generateJob.start();
            } else {
                generateWindow.visible = true;
                generateWindow.statusText = "Task failed";
                generateWindow.hideWindow(5000);
            }
        }

        function updateJobStatus() {
            switch(generateJob.jobStatus) {
            case Enums.JobStatusFailed:
                generateWindow.statusText = "Task failed";
                generateWindow.hideWindow(5000);
                break;
            case Enums.JobStatusNotStarted:
                generateWindow.statusText = "Job not started";
                break;
            case Enums.JobStatusPaused:
                generateWindow.statusText = "Job paused";
                break;
            case Enums.JobStatusStarted:
                generateWindow.statusText = "In progress";
                break;
            case Enums.JobStatusSucceeded:
                generateWindow.statusText = "Loading Map...";
                generateWindow.hideWindow(1500);
                displayOfflineMap(generateJob.result);
                break;
            default:
                console.log("default");
                break;
            }
        }

        function updateProgress() {
            generateWindow.progressText = generateJob.progress;
        }

        function displayOfflineMap(result) {
            // Set the offline map to the MapView
            mapView.map = result.offlineMap;
            downloadButton.visible = false;
            extentRectangle.visible = false;
        }

        Component.onDestruction: {
            if (generateJob) {
                generateJob.jobStatusChanged.disconnect(updateJobStatus);
                generateJob.progressChanged.disconnect(updateProgress);
            }
        }
    }

    GenerateWindow {
        id: generateWindow
        anchors.fill: parent
    }

    /* Uncomment this section when running as standalone application
    AuthenticationView {
        anchors.fill: parent
        authenticationManager: AuthenticationManager
    }
    */
}