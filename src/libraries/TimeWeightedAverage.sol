// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.8;

/// @title Library for getting TWA of a data point in O(1) given just the data stream
library TimeWeightedAverage {
    struct State {
        // checkpoint record is used with latest to calculate twap price
        TimeWeightedAverage.Record checkpoint;
        // will be used as next checkpoint after some time interval
        TimeWeightedAverage.Record checkpointNext;
        // latest record is updated frequently
        TimeWeightedAverage.Record latest;
    }

    // single storage slot
    struct Record {
        int208 cumulative;
        uint48 timestamp;
    }

    /// @notice Reads the state and calculates consumable TWA of the data
    /// @param twa: storage ref to the twa state
    /// @return TWA of the data
    function read(TimeWeightedAverage.State storage twa) internal view returns (int256) {
        // use latest and checkpoint record to derive TWA of the data
        return int256(twa.latest.cumulative - twa.checkpoint.cumulative)
            / int256(uint256(twa.latest.timestamp - twa.checkpoint.timestamp));
    }

    /// @notice Updates the TWA state
    /// @param twa: storage ref to the twa state
    /// @param data: data point
    /// @param interval: interval of checkpoint update (clears entries older than this timestamp for time averaging)
    function update(TimeWeightedAverage.State storage twa, int256 data, uint256 interval)
        internal
    {
        uint256 timestampDelta = block.timestamp - uint256(twa.latest.timestamp);
        if (timestampDelta == 0) return;

        int256 cumulativeIncrease = data * int256(timestampDelta);
        twa.latest.cumulative += int208(cumulativeIncrease); // TODO add check
        twa.latest.timestamp = uint48(block.timestamp);

        // update checkpoint if interval is crossed
        if (twa.latest.timestamp - twa.checkpoint.timestamp > interval) {
            twa.checkpoint = twa.checkpointNext;
        }
        // update checkpoint next if half interval is crossed
        if (twa.latest.timestamp - twa.checkpointNext.timestamp > interval / 2) {
            twa.checkpointNext = twa.latest;
        }
    }
}
