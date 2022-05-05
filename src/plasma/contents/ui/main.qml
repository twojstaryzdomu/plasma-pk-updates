/***************************************************************************
 *   Copyright (C) 2014 by Aleix Pol Gonzalez <aleixpol@blue-systems.com>  *
 *   Copyright (C) 2015 by Lukáš Tinkl <lukas@kde.org>                     *
 *   Copyright (C) 2015 by Jan Grulich <jgrulich@redhat.com>               *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick 2.2
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.PackageKit 1.0

Item
{
    Plasmoid.fullRepresentation: Full {}
    Plasmoid.toolTipSubText: PkUpdates.message
    Plasmoid.icon: PkUpdates.iconName

    Plasmoid.switchWidth: units.gridUnit * 10;
    Plasmoid.switchHeight: units.gridUnit * 10;

    property bool checkDaily: plasmoid.configuration.daily
    property bool checkWeekly: plasmoid.configuration.weekly
    property bool checkMonthly: plasmoid.configuration.monthly

    property bool checkOnMobile: plasmoid.configuration.check_on_mobile
    property bool checkOnBattery: plasmoid.configuration.check_on_battery

    property double lastCheckAttempt: PkUpdates.lastRefreshTimestamp()
    readonly property int secsAutoCheckLimit: 10 * 60

    readonly property int secsInDay: 60 * 60 * 24;
    readonly property int secsInWeek: secsInDay * 7;
    readonly property int secsInMonth: secsInDay * 30;

    readonly property bool networkAllowed: PkUpdates.isNetworkMobile ? checkOnMobile : PkUpdates.isNetworkOnline
    readonly property bool batteryAllowed: PkUpdates.isOnBattery ? checkOnBattery : true

    Timer {
        id: timer
        repeat: true
        triggeredOnStart: true
        interval: 1000 * 60 * 60; // 1 hour
        onTriggered: {
            if (needsForcedUpdate() && networkAllowed && batteryAllowed) {
                lastCheckAttempt = Date.now();
                PkUpdates.checkUpdates(false /* manual */);
            }
        }
    }

    Binding {
        target: plasmoid
        property: "status"
        value: PkUpdates.isActive || (!PkUpdates.isSystemUpToDate && isAnySelected()) ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus;
    }

    Plasmoid.compactRepresentation: PlasmaCore.IconItem {
        source: PkUpdates.iconName
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }
    }

    function needsForcedUpdate() {
        if ((Date.now() - lastCheckAttempt)/1000 < secsAutoCheckLimit) {
            return false;
        }

        var secs = (Date.now() - PkUpdates.lastRefreshTimestamp())/1000; // compare with the saved timestamp
        if (secs < 0) { // never checked before
            return true;
        } else if (checkDaily) {
            return secs >= secsInDay;
        } else if (checkWeekly) {
            return secs >= secsInWeek;
        } else if (checkMonthly) {
            return secs >= secsInMonth;
        }
        return false;
    }

    function isAnySelected() {
        for (var i = 0; i < updatesModel.count; i++) {
            var pkg = updatesModel.get(i)
            if (pkg.selected)
                return true;
        }
        return false;
    }

    Connections {
        target: PkUpdates
        onNetworkStateChanged: timer.restart()
        onIsOnBatteryChanged: timer.restart()
    }

    Component.onCompleted: {
        timer.start()
    }
}
