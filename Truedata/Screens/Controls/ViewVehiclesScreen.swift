//
//  ViewVehiclesScreen.swift
//  Truedata
//

import SwiftUI

struct ViewVehiclesScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ViewVehiclesViewModel()
    @State private var historyTarget: AdminVehicleItem?
    @State private var deleteTarget: AdminVehicleItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "View Vehicles",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load() }
                )

                VehicleListTabBar(selectedTab: $viewModel.selectedTab)
                searchBar
                content
            }

            if !viewModel.isLoading && viewModel.errorMessage == nil {
                AttendanceFloatingAddButton {
                    viewModel.prepareAddVehicle()
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }

            if viewModel.isSaving || viewModel.isAssigning {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView(viewModel.isAssigning ? "Updating assignment..." : "Saving...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .navigationDestination(item: $historyTarget) { vehicle in
            VehicleHistoryScreen(vehicleId: vehicle.id)
        }
        .sheet(isPresented: $viewModel.showVehicleForm) {
            VehicleFormSheet(
                form: $viewModel.vehicleForm,
                isLoading: viewModel.isSaving,
                onSave: { viewModel.saveVehicle() },
                onDismiss: { viewModel.showVehicleForm = false }
            )
        }
        .sheet(isPresented: $viewModel.showAssignSheet) {
            AssignVehicleSheet(
                riders: viewModel.availableRiders,
                selectedRiderId: $viewModel.selectedRiderId,
                isLoading: viewModel.isAssigning,
                onSubmit: { viewModel.assignVehicle() },
                onDismiss: { viewModel.dismissAssignmentDialogs() }
            )
        }
        .alert("Delete Vehicle", isPresented: deleteBinding) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Confirm", role: .destructive) {
                if let vehicle = deleteTarget {
                    viewModel.deleteVehicle(vehicle)
                }
                deleteTarget = nil
            }
        } message: {
            if let vehicle = deleteTarget {
                Text("Are you sure you want to delete \(vehicle.name)?")
            }
        }
        .alert("Unassign Vehicle", isPresented: unassignBinding) {
            Button("Cancel", role: .cancel) { viewModel.dismissAssignmentDialogs() }
            Button("Unassign", role: .destructive) {
                viewModel.unassignVehicle()
            }
        } message: {
            if let vehicle = viewModel.selectedVehicle {
                Text("Are you sure you want to unassign \(vehicle.name)? The vehicle will become available for other riders.")
            }
        }
        .alert("Notice", isPresented: toastBinding) {
            Button("OK", role: .cancel) { viewModel.toastMessage = nil }
        } message: {
            Text(viewModel.toastMessage ?? "")
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private var unassignBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showUnassignDialog },
            set: { if !$0 { viewModel.dismissAssignmentDialogs() } }
        )
    }

    private var toastBinding: Binding<Bool> {
        Binding(
            get: { viewModel.toastMessage != nil },
            set: { if !$0 { viewModel.toastMessage = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.vehicles.isEmpty && viewModel.riders.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField("Search vehicles or riders...", text: $viewModel.searchText)
                .font(.system(size: 15))
            if !viewModel.searchText.isEmptyString {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.vehicles.isEmpty {
            ProgressView("Loading vehicles...")
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.vehicles.isEmpty && viewModel.riders.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Try Again") {
                    viewModel.load()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.selectedTab == .vehicles {
                        if viewModel.filteredVehicles.isEmpty {
                            emptyState(
                                title: "No Vehicles Found",
                                message: "Add your first vehicle using the + button"
                            )
                        } else {
                            ForEach(viewModel.filteredVehicles) { vehicle in
                                VehicleCard(
                                    vehicle: vehicle,
                                    onEdit: { viewModel.prepareEditVehicle(vehicle) },
                                    onHistory: { historyTarget = vehicle },
                                    onDelete: { deleteTarget = vehicle },
                                    onAssign: { viewModel.openAssignSheet(for: vehicle) },
                                    onUnassign: { viewModel.openUnassignDialog(for: vehicle) }
                                )
                            }
                        }
                    } else {
                        if viewModel.filteredRiders.isEmpty {
                            emptyState(
                                title: "No Riders Found",
                                message: "No riders are currently registered"
                            )
                        } else {
                            ForEach(viewModel.filteredRiders) { rider in
                                RiderVehicleCard(rider: rider)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 96)
            }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
