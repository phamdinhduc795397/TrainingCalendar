import SwiftUI

struct TrainingCalendarScreen: View {
    @State var viewModel: TrainingCalendarViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: CalendarDesignTokens.daySpacing) {
                    ForEach(viewModel.days) { day in
                        DayContainerView(
                            day: day,
                            isLoading: viewModel.phase == .loading,
                            onWorkoutTap: { id in
                                Task { await viewModel.toggleCompletion(workoutID: id) }
                            }
                        )
                    }

                    if case .initialError(let message) = viewModel.phase {
                        errorView(message)
                    } else if let message = viewModel.refreshErrorMessage {
                        errorView(message)
                    }
                }
                .padding(.horizontal, CalendarDesignTokens.screenHorizontalPadding)
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
