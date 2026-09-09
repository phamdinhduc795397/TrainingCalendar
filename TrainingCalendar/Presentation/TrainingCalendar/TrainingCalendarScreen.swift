import SwiftUI

struct TrainingCalendarScreen: View {
    @State var viewModel: TrainingCalendarViewModel
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: CalendarDesignTokens.daySpacing) {
                    ForEach(viewModel.days) { day in
                        DayContainerView(day: day, isLoading: viewModel.phase == .loading) { id in
                            Task { await viewModel.toggleCompletion(workoutID: id) }
                        }
                    }
                    if case .initialError(let message) = viewModel.phase {
                        errorView(message)
                    } else if let message = viewModel.refreshErrorMessage {
                        errorView(message)
                    }
                    
                    if let message = viewModel.completionErrorMessage {
                        Text(message)
                            .font(.footnote)
                            .accessibilityIdentifier("completion-error")
                    }
                }
                .padding(.horizontal, CalendarDesignTokens.screenHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Training Calendar")
            .overlay(alignment: .topTrailing) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .padding()
                }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshDateDependentPresentation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            viewModel.refreshDateDependentPresentation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            viewModel.refreshDateDependentPresentation(calendar: .current)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: CalendarDesignTokens.errorSpacing) {
            Text(message)
                .font(.footnote)
            Button("Retry") {
                Task { await viewModel.retry() }
            }
        }
        .accessibilityIdentifier("calendar-error")
    }
}
