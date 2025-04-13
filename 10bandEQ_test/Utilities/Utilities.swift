//
//  Utilities.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/04/13.
// 共通ユーティリティ関数をまとめたファイル

import Foundation

/// 値を最小値と最大値の範囲に収める汎用clamp関数
@inline(__always)
func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    return min(max(value, minValue), maxValue)
}
