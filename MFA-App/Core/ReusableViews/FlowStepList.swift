//
//  FlowStepList.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

protocol FlowStep: RawRepresentable, CaseIterable, Hashable where RawValue == Int {
    var title: String { get }
    var systemImage: String { get }
}

struct FlowStepList<Step: FlowStep>: View {
    let currentStep: Step?
    let isFinished: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(Step.allCases), id: \.self) { step in
                StepRow(title: step.title, systemImage: step.systemImage, status: status(for: step))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func status(for step: Step) -> StepStatus {
        guard !isFinished else { return .done }
        guard let currentStep else { return .pending }

        if step.rawValue < currentStep.rawValue { return .done }
        return step.rawValue == currentStep.rawValue ? .active : .pending
    }
}
