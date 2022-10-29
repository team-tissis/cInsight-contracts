// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

library QuickSort {
    
    function sort(uint32[] memory data, uint16[] memory ind) public returns (uint16[] memory) {
       quickSort(data, ind, int(0), int(data.length - 1));
       return ind;
    }

    // descending
    function quickSort(uint32[] memory arr, uint16[] memory ind, int left, int right) internal{
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] > pivot) i++;
            while (pivot > arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                (ind[uint(i)], ind[uint(j)]) = (ind[uint(j)], ind[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, ind, left, j);
        if (i < right)
            quickSort(arr, ind, i, right);
    }
}
