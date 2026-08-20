//
//  AttendanceDetailSheet.swift
//  Truedata
//

import SwiftUI

struct AttendanceDetailSheet: View {
    let item: AttendanceHistoryItem
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    AttendanceReadOnlyField(label: "In Time", value: item.inTime)
                    AttendanceReadOnlyField(label: "In Time Address", value: item.inTimeAddress, minLines: 3)

                    if let outTime = item.outTime, !outTime.isEmpty {
                        AttendanceReadOnlyField(label: "Out Time", value: outTime)
                    }

                    if let outAddress = item.outTimeAddress, !outAddress.isEmpty {
                        AttendanceReadOnlyField(label: "Out Time Address", value: outAddress, minLines: 3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(Color.white)
    }

    private var sheetHeader: some View {
        HStack {
            Text("Attendance Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.darkMidnightBlue)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.slateGray)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "E5E7EB"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct AttendanceReadOnlyField: View {
    let label: String
    let value: String
    var minLines: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.cerulean)

            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.darkMidnightBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, minLines > 1 ? 12 : 0)
                .frame(minHeight: 52, alignment: .topLeading)
                .background(AppTheme.aliceBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2)
                }
        }
    }
}
