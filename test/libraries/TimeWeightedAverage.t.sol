// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/libraries/TimeWeightedAverage.sol";

contract TimeWeightedAverageTest is Test {
    using TimeWeightedAverage for TimeWeightedAverage.State;

    TimeWeightedAverage.State twa;

    function setUp() public {
        vm.warp(100000);
    }

    //
    // Initialisation tests
    //
    function test_TimeWeightedAverage_firstUpdate() public {
        twa.update({data: 100, interval: 10});

        // after first update, the value that is read should be the first value
        assertEq(twa.read(), 100);

        // updates latest record
        assertEq(
            twa.latest.cumulative,
            toInt208(100 * block.timestamp),
            "updates latest record cumulative"
        );
        assertEq(twa.latest.timestamp, block.timestamp, "updates latest record timestamp");

        // updates checkpointNext record
        assertEq(
            twa.checkpointNext.cumulative,
            toInt208(100 * block.timestamp),
            "updates checkpointNext record cumulative"
        );
        assertEq(
            twa.checkpointNext.timestamp, block.timestamp, "updates checkpointNext record timestamp"
        );

        // does not update checkpoint record (to ensure latest and checkpoint are at different timestamps)
        assertEq(twa.checkpoint.cumulative, 0, "does not update checkpoint record cumulative");
        assertEq(twa.checkpoint.timestamp, 0, "does not update checkpoint record timestamp");

        delete twa;
    }

    function test_TimeWeightedAverage_twoUpdatesAtSameTime() public {
        twa.update({data: 100, interval: 10});
        twa.update({data: 200, interval: 10});

        assertEq(twa.read(), 100);

        // does not overwrite latest record
        assertEq(
            twa.latest.cumulative,
            toInt208(100 * block.timestamp),
            "updates latest record cumulative"
        );
        assertEq(twa.latest.timestamp, block.timestamp, "updates latest record timestamp");

        // does not overwrite checkpointNext record
        assertEq(
            twa.checkpointNext.cumulative,
            toInt208(100 * block.timestamp),
            "updates checkpointNext record cumulative"
        );
        assertEq(
            twa.checkpointNext.timestamp, block.timestamp, "updates checkpointNext record timestamp"
        );

        // does not update checkpoint record (to ensure latest and checkpoint are at different timestamps)
        assertEq(twa.checkpoint.cumulative, 0, "does not update checkpoint record cumulative");
        assertEq(twa.checkpoint.timestamp, 0, "does not update checkpoint record timestamp");

        delete twa;
    }

    function test_TimeWeightedAverage_twoUpdatesAfterSec() public {
        uint256 timestamp1 = block.timestamp;
        twa.update({data: 100, interval: 10});

        uint256 timestamp2 = block.timestamp + 1;
        vm.warp(timestamp2);

        TimeWeightedAverage.Record memory checkpointNextOld = twa.checkpointNext;

        twa.update({data: 200, interval: 10});

        assertEq(twa.read(), 200); // gives twa of just 200 data point, its 200 (100 data point goes in checkpoint)

        // updates latest record due to timestamp change
        assertEq(
            twa.latest.cumulative,
            toInt208(100 * timestamp1) + toInt208(200 * (timestamp2 - timestamp1)),
            "updates latest record cumulative"
        );
        assertEq(twa.latest.timestamp, timestamp2, "updates latest record timestamp");

        // checkpointNext record does not update to latest
        assertEq(
            twa.checkpointNext.cumulative,
            checkpointNextOld.cumulative,
            "does not update checkpointNext record cumulative"
        );
        assertEq(
            twa.checkpointNext.timestamp,
            checkpointNextOld.timestamp,
            "does not update checkpointNext record timestamp"
        );

        // checkpoint is updated to checkpointNext
        assertEq(
            twa.checkpoint.cumulative,
            toInt208(100 * timestamp1),
            "updates checkpoint record cumulative"
        );
        assertEq(twa.checkpoint.timestamp, timestamp1, "updates checkpoint record timestamp");

        delete twa;
    }

    //
    // TWA tests
    //
    function test_TimeWeightedAverage_singleObservation() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);

        assertEq(twa.read(), v1, "single observation should give same price");
    }

    function test_TimeWeightedAverage_twoObservationSimpleAverage() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);

        int256 v2 = 300;
        uint256 t2 = t1;
        vm.warp(block.timestamp + t2);
        twa.update({data: v2, interval: 1000});

        assertEq(twa.read(), (v1 + v2) / 2, "t1 == t2 should cause perfect average");
    }

    function test_TimeWeightedAverage_twoObservationWeightedAverage() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);

        int256 v2 = 400;
        uint256 t2 = 20;
        twaObserve({newData: v2, timeIncrease: t2});

        assertEq(
            twa.read(),
            (v1 * toInt208(t1) + v2 * toInt208(t2)) / toInt208(t1 + t2),
            "should calculate weighted average"
        );
    }

    function test_TimeWeightedAverage_threeObservationSimpleAverage() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);

        int256 v2 = 200;
        uint256 t2 = 10;
        twaObserve({newData: v2, timeIncrease: t2});

        int256 v3 = 300;
        uint256 t3 = 10;
        twaObserve({newData: v3, timeIncrease: t3});

        assertEq(twa.read(), (v1 + v2 + v3) / 3, "should calculate simple average");
    }

    function test_TimeWeightedAverage_threeObservationWeightedAverage() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);
        TimeWeightedAverage.Record memory checkpointNextJustAfterSetup = twa.checkpointNext;

        int256 v2 = 200;
        uint256 t2 = 20;
        twaObserve({newData: v2, timeIncrease: t2});

        int256 v3 = 300;
        uint256 t3 = 30;
        twaObserve({newData: v3, timeIncrease: t3});

        assertEq(
            twa.read(),
            (v1 * toInt208(t1) + v2 * toInt208(t2) + v3 * toInt208(t3)) / toInt208(t1 + t2 + t3),
            "should calculate weighted average"
        );

        // checkpointNext record does not update to latest before reaching half interval
        assertEq(
            twa.checkpointNext.cumulative,
            checkpointNextJustAfterSetup.cumulative,
            "does not update checkpointNext record cumulative"
        );
        assertEq(
            twa.checkpointNext.timestamp,
            checkpointNextJustAfterSetup.timestamp,
            "does not update checkpointNext record timestamp"
        );
    }

    function test_TimeWeightedAverage_interval_half() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);

        int256 v2 = 200;
        uint256 t2 = 20;
        twaObserve({newData: v2, timeIncrease: t2});

        // making an update after half interval
        int256 v3 = 300;
        uint256 t3 = 0.5 days + 30;
        twaObserve({newData: v3, timeIncrease: t3});

        // old observations including #3 are cleared
        assertEq(
            twa.read(),
            (v1 * toInt208(t1) + v2 * toInt208(t2) + v3 * toInt208(t3)) / toInt208(t1 + t2 + t3),
            "should calculate weighted average"
        );

        // checkpointNext record updates to latest
        assertEq(
            twa.checkpointNext.cumulative,
            twa.checkpointNext.cumulative,
            "updates checkpointNext record cumulative"
        );
        assertEq(
            twa.checkpointNext.timestamp,
            twa.checkpointNext.timestamp,
            "updates checkpointNext record timestamp"
        );
    }

    function test_TimeWeightedAverage_interval_full() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);

        int256 v2 = 200;
        uint256 t2 = 20;
        twaObserve({newData: v2, timeIncrease: t2});

        // making an update after half interval
        int256 v3 = 300;
        uint256 t3 = 0.5 days;
        twaObserve({newData: v3, timeIncrease: t3});
        TimeWeightedAverage.Record memory latestAfter3 = twa.latest;

        int256 v4 = 400;
        uint256 t4 = 40;
        twaObserve({newData: v4, timeIncrease: t4});

        // making an update after full interval
        int256 v5 = 500;
        uint256 t5 = 0.5 days;
        twaObserve({newData: v5, timeIncrease: t5});

        int256 v6 = 600;
        uint256 t6 = 60;
        twaObserve({newData: v6, timeIncrease: t6});

        // old observations including #3 are cleared
        assertEq(
            twa.read(),
            (v4 * toInt208(t4) + v5 * toInt208(t5) + v6 * toInt208(t6)) / toInt208(t4 + t5 + t6),
            "should calculate weighted average using #4, #5, #6"
        );

        // checkpoint record updates to #3
        assertEq(
            twa.checkpoint.cumulative,
            latestAfter3.cumulative,
            "updates checkpoint record cumulative"
        );
        assertEq(
            twa.checkpoint.timestamp, latestAfter3.timestamp, "updates checkpoint record timestamp"
        );
    }

    function test_TimeWeightedAverage_interval_delayedObservations() public {
        int256 v1 = 100;
        uint256 t1 = 10;
        twaSetup(v1, t1);

        int256 v2 = 200;
        uint256 t2 = 20;
        twaObserve({newData: v2, timeIncrease: t2});

        // making an update after 1 days
        int256 v3 = 300;
        uint256 t3 = 1 days + 30;
        twaObserve({newData: v3, timeIncrease: t3});

        // still uses old observations, to prevent TWA with single observation
        assertEq(
            twa.read(),
            (v1 * toInt208(t1) + v2 * toInt208(t2) + v3 * toInt208(t3)) / toInt208(t1 + t2 + t3),
            "should calculate weighted average"
        );
    }

    //
    // Utils
    //
    function twaSetup(int256 v1, uint256 t1) internal {
        delete twa;
        twa.update({data: 0, interval: 1 days});

        vm.warp(block.timestamp + t1);
        twa.update({data: v1, interval: 1 days});
    }

    function twaObserve(int256 newData, uint256 timeIncrease) internal {
        vm.warp(block.timestamp + timeIncrease);
        twa.update({data: newData, interval: 1 days});
    }

    event LogTwaRecord(string name, TimeWeightedAverage.Record record);

    function logTwa() internal {
        emit LogTwaRecord("latest", twa.latest);
        emit LogTwaRecord("checkpoint", twa.checkpoint);
        emit LogTwaRecord("checkpointNext", twa.checkpointNext);
    }

    function toInt208(uint256 val) internal pure returns (int208) {
        return int208(int256(val));
    }
}
