// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library DateTimeLibrary {
  uint constant SECONDS_PER_DAY = 24 * 60 * 60;
  uint constant SECONDS_PER_HOUR = 60 * 60;
  uint constant SECONDS_PER_MINUTE = 60;
  int constant OFFSET19700101 = 2440588;

  uint constant DOW_MON = 1;
  uint constant DOW_TUE = 2;
  uint constant DOW_WED = 3;
  uint constant DOW_THU = 4;
  uint constant DOW_FRI = 5;
  uint constant DOW_SAT = 6;
  uint constant DOW_SUN = 7;

  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
      return "0";
    }
    uint j = _i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len;
    while (_i != 0) {
      k = k-1;
      uint8 temp = (48 + uint8(_i - _i / 10 * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
  }

  // ------------------------------------------------------------------------
  // Calculate the number of days from 1970/01/01 to year/month/day using
  // the date conversion algorithm from
  //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
  // and subtracting the offset 2440588 so that 1970/01/01 is day 0
  //
  // days = day
  //      - 32075
  //      + 1461 * (year + 4800 + (month - 14) / 12) / 4
  //      + 367 * (month - 2 - (month - 14) / 12 * 12) / 12
  //      - 3 * ((year + 4900 + (month - 14) / 12) / 100) / 4
  //      - offset
  // ------------------------------------------------------------------------
  function _daysFromDate(uint year, uint month, uint day) internal pure returns (uint _days) {
    require(year >= 1970);
    int _year = int(year);
    int _month = int(month);
    int _day = int(day);

    int __days = _day
      - 32075
      + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
      + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
      - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
      - OFFSET19700101;

    _days = uint(__days);
  }

  // ------------------------------------------------------------------------
  // Calculate year/month/day from the number of days since 1970/01/01 using
  // the date conversion algorithm from
  //   http://aa.usno.navy.mil/faq/docs/JD_Formula.php
  // and adding the offset 2440588 so that 1970/01/01 is day 0
  //
  // int L = days + 68569 + offset
  // int N = 4 * L / 146097
  // L = L - (146097 * N + 3) / 4
  // year = 4000 * (L + 1) / 1461001
  // L = L - 1461 * year / 4 + 31
  // month = 80 * L / 2447
  // dd = L - 2447 * month / 80
  // L = month / 11
  // month = month + 2 - 12 * L
  // year = 100 * (N - 49) + year + L
  // ------------------------------------------------------------------------
  function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
    int __days = int(_days);

    int L = __days + 68569 + OFFSET19700101;
    int N = 4 * L / 146097;
    L = L - (146097 * N + 3) / 4;
    int _year = 4000 * (L + 1) / 1461001;
    L = L - 1461 * _year / 4 + 31;
    int _month = 80 * L / 2447;
    int _day = L - 2447 * _month / 80;
    L = _month / 11;
    _month = _month + 2 - 12 * L;
    _year = 100 * (N - 49) + _year + L;

    year = uint(_year);
    month = uint(_month);
    day = uint(_day);
  }

  function timestampFromDate(uint year, uint month, uint day) internal pure returns (uint timestamp) {
    timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY;
  }
  function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
    timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
  }
  function timestampToDate(uint timestamp) internal pure returns (uint year, uint month, uint day) {
    (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
  }
  function timestampToDateTime(uint timestamp) internal pure returns (uint year, uint month, uint day, uint hour, uint minute, uint second) {
    (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    uint secs = timestamp % SECONDS_PER_DAY;
    hour = secs / SECONDS_PER_HOUR;
    secs = secs % SECONDS_PER_HOUR;
    minute = secs / SECONDS_PER_MINUTE;
    second = secs % SECONDS_PER_MINUTE;
  }
  function timestampToTimeBlocks(uint timestamp) internal pure returns (bytes32 monthId, bytes32 weekId, bytes32 dayId) {
    uint256 dayOfWeek = getDayOfWeek(timestamp);
    (uint year, uint month, uint day) = timestampToDate(timestamp);
    uint weekYear;
    uint weekMonth;
    uint weekDay;

    if (dayOfWeek > 1) {
      (weekYear, weekMonth, weekDay) = timestampToDate(subDays(timestamp, dayOfWeek - 1));
    } else {
      (weekYear, weekMonth, weekDay) = (year, month, day);
    }

    monthId = bytes32(abi.encodePacked(uint2str(year), "-", uint2str(month)));
    weekId = bytes32(abi.encodePacked(uint2str(weekYear), "-", uint2str(weekMonth), "-", uint2str(weekDay)));
    dayId = bytes32(abi.encodePacked(uint2str(year), "-", uint2str(month), "-", uint2str(day)));
  }
  // 1 = Monday, 7 = Sunday
  function getDayOfWeek(uint256 timestamp) internal pure returns (uint256 dayOfWeek) {
    uint256 _days = timestamp / SECONDS_PER_DAY;
    dayOfWeek = ((_days + 3) % 7) + 1;
  }
  function subDays(uint256 timestamp, uint256 _days) internal pure returns (uint256 newTimestamp) {
    newTimestamp = timestamp - _days * SECONDS_PER_DAY;
    require(newTimestamp <= timestamp);
  }
}