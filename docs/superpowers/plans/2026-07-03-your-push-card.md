# YourPushCard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `ActivePlanCard` in the "Your Pushes" module with a distinct two-zone `YourPushCard` that shows a walnut outline time chip, a non-overlapping participant avatar row, and a "Manage →" text CTA.

**Architecture:** Add `participants: [HangoutPerson]` (default `[]`) to `PlanData` and populate mock data for the two owned plans. Build `YourPushCard` as a self-contained file with private sub-components. Wire it into `PlansView` via a new `isManagePushPresented` flag on `PlansViewModel`.

**Tech Stack:** SwiftUI, MVVM, mock data only, iOS 17+, XCTest for model tests.

## Global Constraints

- All colors use `PushControlColors` / `PushColorPalette` tokens only — no raw color literals
- All layout values in named constants (enums in `PlansStyle.swift` or `YourPushCard.swift`)
- Files ≤ 400 lines; functions ≤ 40 lines
- No real network or location calls — mock data only
- `participants` must default to `[]` so all existing test `PlanData` initialisers compile without changes
- "Manage →" is a text CTA, not a filled button
- Avatars are non-overlapping (HStack, not ZStack offset)

---

### Task 1: Extend `PlanData` model and update mock data

**Files:**
- Modify: `Push/PlansModels.swift`
- Test: `PushTests/PlansViewModelTests.swift`

**Interfaces:**
- Produces: `PlanData` with `let participants: [HangoutPerson]` (default `[]`)
- Produces: `PlansMockData.plans` where `"gym-later"` has 4 participants and `"drinks-friday"` has 2

- [ ] **Step 1: Write a failing test**

Add this test to `PushTests/PlansViewModelTests.swift`:

```swift
func testYourPushes_ownedPlansHaveParticipants() {
    let vm = PlansViewModel(plans: PlansMockData.plans)
    let owned = vm.yourPushes
    XCTAssertTrue(owned.allSatisfy { !$0.participants.isEmpty },
                  "Each owned push should have at least one participant")
}
```

- [ ] **Step 2: Run test to verify it fails**

In Xcode: Product → Test (⌘U), filter to `testYourPushes_ownedPlansHaveParticipants`.
Expected: compile error — `PlanData` has no `participants` member.

- [ ] **Step 3: Add `participants` to `PlanData`**

In `Push/PlansModels.swift`, replace the `PlanData` struct with:

```swift
struct PlanData: Identifiable {
    let id: String
    let title: String
    let group: String
    let timeSignal: String
    let socialProof: String
    let locationHint: String
    var status: PlanStatus
    let isOwner: Bool
    let participants: [HangoutPerson]

    init(
        id: String,
        title: String,
        group: String,
        timeSignal: String,
        socialProof: String,
        locationHint: String,
        status: PlanStatus,
        isOwner: Bool,
        participants: [HangoutPerson] = []
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.timeSignal = timeSignal
        self.socialProof = socialProof
        self.locationHint = locationHint
        self.status = status
        self.isOwner = isOwner
        self.participants = participants
    }
}
```

- [ ] **Step 4: Update `PlansMockData.plans` with participants**

In `Push/PlansModels.swift`, replace the `PlansMockData.plans` array with:

```swift
static let plans: [PlanData] = [
    PlanData(
        id: "food-tonight",
        title: "Food tonight?",
        group: "Michigan",
        timeSignal: "8:00 PM",
        socialProof: "3 in · 2 maybe",
        locationHint: "Suggested: North Park",
        status: .pending,
        isOwner: false
    ),
    PlanData(
        id: "gym-later",
        title: "Gym later",
        group: "Exec",
        timeSignal: "~7:45 PM",
        socialProof: "4 going",
        locationHint: "Crunch Fitness",
        status: .joined,
        isOwner: true,
        participants: [
            HangoutPerson(id: "chitty",  name: "Chitty",  imageAssetName: "assets/friends/chitty.png",  initials: "CH"),
            HangoutPerson(id: "ishan",   name: "Ishan",   imageAssetName: "assets/friends/ishan.png",   initials: "IS"),
            HangoutPerson(id: "viplove", name: "Viplove", imageAssetName: "assets/friends/viplove.png", initials: "VI"),
            HangoutPerson(id: "ram",     name: "Ram",     imageAssetName: "assets/friends/ram.png",     initials: "RA")
        ]
    ),
    PlanData(
        id: "coffee",
        title: "Coffee?",
        group: "India",
        timeSignal: "now",
        socialProof: "Chitty is there · Ishan maybe",
        locationHint: "Blue Bottle",
        status: .open,
        isOwner: false
    ),
    PlanData(
        id: "drinks-friday",
        title: "Drinks Friday?",
        group: "Michigan",
        timeSignal: "Friday, 9:00 PM",
        socialProof: "2 in · 1 maybe",
        locationHint: "Suggested: Little Italy",
        status: .pending,
        isOwner: true,
        participants: [
            HangoutPerson(id: "rohan", name: "Rohan", imageAssetName: "assets/friends/rohan.png", initials: "RO"),
            HangoutPerson(id: "ryan",  name: "Ryan",  imageAssetName: "assets/friends/ryan.png",  initials: "RY")
        ]
    ),
    PlanData(
        id: "poker-night",
        title: "Poker night",
        group: "Exec",
        timeSignal: "Saturday",
        socialProof: "Ram in · Ohm maybe",
        locationHint: "Ram's place",
        status: .waiting,
        isOwner: false
    )
]
```

- [ ] **Step 5: Run tests to verify all pass**

⌘U in Xcode. All existing tests should still pass (default `participants: []` means old initialisers compile). New test should now pass.

- [ ] **Step 6: Commit**

```bash
git add Push/PlansModels.swift PushTests/PlansViewModelTests.swift
git commit -m "feat: add participants to PlanData, seed mock data for owned plans"
```

---

### Task 2: Add `YourPushCardLayout` constants to `PlansStyle.swift`

**Files:**
- Modify: `Push/PlansStyle.swift`

**Interfaces:**
- Produces: `YourPushCardLayout` enum with the constants used in Tasks 3–4

No new tests needed — pure constants.

- [ ] **Step 1: Append `YourPushCardLayout` to `Push/PlansStyle.swift`**

Add at the bottom of the file:

```swift
enum YourPushCardLayout {
    static let avatarSize: CGFloat = 28
    static let avatarSpacing: CGFloat = 6
    static let avatarStrokeWidth: CGFloat = 0.8
    static let overflowAvatarSize: CGFloat = 28
    static let maxVisibleAvatars: Int = 4
    static let timeChipHorizontalPadding: CGFloat = 8
    static let timeChipVerticalPadding: CGFloat = 4
    static let timeChipStrokeOpacity: Double = 0.40
    static let joinedLabelSpacing: CGFloat = 6
    static let footerTopPadding: CGFloat = 4
}
```

- [ ] **Step 2: Commit**

```bash
git add Push/PlansStyle.swift
git commit -m "feat: add YourPushCardLayout constants"
```

---

### Task 3: Create `YourPushCard.swift`

**Files:**
- Create: `Push/YourPushCard.swift`

**Interfaces:**
- Consumes: `PlanData` (with `participants: [HangoutPerson]` from Task 1)
- Consumes: `YourPushCardLayout` (from Task 2)
- Consumes: `ProfilePhotoAvatar(imageAssetName:fallbackInitials:)` from `FriendPuckStyle.swift`
- Consumes: `pushGlassBackground(cornerRadius:)` from `PushGlassStyle.swift`
- Consumes: `PlansLayout.cardCornerRadius`, `PlansLayout.cardPadding`, `PlansLayout.cardRowSpacing`
- Consumes: `PushControlColors.textEspresso/textPrimary/textSecondary/textTertiary`
- Consumes: `PushColorPalette.Accent.walnut`, `PushColorPalette.Accent.sunbeam`
- Produces: `struct YourPushCard: View` — public, takes `plan: PlanData` and `onManage: () -> Void`

No unit tests for pure SwiftUI views in this project — verify visually in simulator (Task 5).

- [ ] **Step 1: Create the file**

Create `Push/YourPushCard.swift` with this content:

```swift
// Push/YourPushCard.swift
import SwiftUI

struct YourPushCard: View {
    let plan: PlanData
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing) {
            headerRow
            groupLocationRow
            Divider()
                .background(PushColorPalette.Accent.walnut.opacity(0.12))
            joinedSection
            footerRow
        }
        .padding(PlansLayout.cardPadding)
        .pushGlassBackground(cornerRadius: PlansLayout.cardCornerRadius)
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
            Spacer(minLength: 8)
            YourPushTimeChip(timeSignal: plan.timeSignal)
        }
    }

    private var groupLocationRow: some View {
        Text("\(plan.group) · \(plan.locationHint)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PushControlColors.textSecondary)
            .lineLimit(1)
    }

    private var joinedSection: some View {
        VStack(alignment: .leading, spacing: YourPushCardLayout.joinedLabelSpacing) {
            Text("Joined:")
                .font(.caption.weight(.medium))
                .foregroundStyle(PushControlColors.textTertiary)
            YourPushAvatarRow(participants: plan.participants)
        }
    }

    private var footerRow: some View {
        HStack {
            Text(plan.socialProof)
                .font(.footnote)
                .foregroundStyle(PushControlColors.textSecondary)
            Spacer()
            Button(action: onManage) {
                Text("Manage →")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PushControlColors.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, YourPushCardLayout.footerTopPadding)
    }
}

private struct YourPushTimeChip: View {
    let timeSignal: String

    var body: some View {
        Text(timeSignal)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PushControlColors.textPrimary)
            .padding(.horizontal, YourPushCardLayout.timeChipHorizontalPadding)
            .padding(.vertical, YourPushCardLayout.timeChipVerticalPadding)
            .overlay {
                Capsule()
                    .stroke(
                        PushColorPalette.Accent.walnut.opacity(YourPushCardLayout.timeChipStrokeOpacity),
                        lineWidth: 1
                    )
            }
    }
}

private struct YourPushAvatarRow: View {
    let participants: [HangoutPerson]

    private var visible: [HangoutPerson] {
        Array(participants.prefix(YourPushCardLayout.maxVisibleAvatars))
    }

    private var overflowCount: Int {
        max(0, participants.count - YourPushCardLayout.maxVisibleAvatars)
    }

    var body: some View {
        HStack(spacing: YourPushCardLayout.avatarSpacing) {
            ForEach(visible) { person in
                ProfilePhotoAvatar(
                    imageAssetName: person.imageAssetName,
                    fallbackInitials: person.initials
                )
                .frame(
                    width: YourPushCardLayout.avatarSize,
                    height: YourPushCardLayout.avatarSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(0.86),
                            lineWidth: YourPushCardLayout.avatarStrokeWidth
                        )
                }
            }
            if overflowCount > 0 {
                YourPushOverflowBubble(count: overflowCount)
            }
        }
    }
}

private struct YourPushOverflowBubble: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(PushControlColors.textPrimary)
            .frame(
                width: YourPushCardLayout.overflowAvatarSize,
                height: YourPushCardLayout.overflowAvatarSize
            )
            .background(
                Circle().fill(PushColorPalette.Accent.sunbeam)
            )
    }
}
```

- [ ] **Step 2: Verify the file compiles**

In Xcode: Product → Build (⌘B). Expected: build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Push/YourPushCard.swift
git commit -m "feat: add YourPushCard with time chip, avatar row, and Manage CTA"
```

---

### Task 4: Create `ManagePushView.swift` (placeholder)

**Files:**
- Create: `Push/ManagePushView.swift`

**Interfaces:**
- Produces: `struct ManagePushView: View` — public, takes `plan: PlanData` and `onDismiss: () -> Void`

- [ ] **Step 1: Create the file**

Create `Push/ManagePushView.swift` with this content:

```swift
// Push/ManagePushView.swift
import SwiftUI

struct ManagePushView: View {
    let plan: PlanData
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: 16) {
                Text(plan.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                Text("Manage coming soon")
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textTertiary)
            }
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close manage push") {
                onDismiss()
            }
        }
    }
}
```

- [ ] **Step 2: Verify the file compiles**

⌘B in Xcode. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Push/ManagePushView.swift
git commit -m "feat: add ManagePushView placeholder"
```

---

### Task 5: Wire up `PlansViewModel` and `PlansView`

**Files:**
- Modify: `Push/PlansViewModel.swift`
- Modify: `Push/PlansView.swift`
- Test: `PushTests/PlansViewModelTests.swift`

**Interfaces:**
- Consumes: `YourPushCard(plan:onManage:)` from Task 3
- Consumes: `ManagePushView(plan:onDismiss:)` from Task 4
- Consumes: `isManagePushPresented: Bool` and `managedPlan: PlanData?` added to `PlansViewModel`

- [ ] **Step 1: Write a failing test for the new ViewModel state**

Add to `PushTests/PlansViewModelTests.swift`:

```swift
func testIsManagePushPresented_defaultsFalse() {
    let vm = PlansViewModel()
    XCTAssertFalse(vm.isManagePushPresented)
    XCTAssertNil(vm.managedPlan)
}
```

- [ ] **Step 2: Run test to verify it fails**

⌘U. Expected: compile error — `isManagePushPresented` and `managedPlan` not on `PlansViewModel`.

- [ ] **Step 3: Add state to `PlansViewModel`**

In `Push/PlansViewModel.swift`, add after `@Published var isYourPushesPresented`:

```swift
@Published var isManagePushPresented: Bool = false
@Published var managedPlan: PlanData? = nil
```

- [ ] **Step 4: Run tests to verify they pass**

⌘U. All tests including the new one should pass.

- [ ] **Step 5: Update `YourPushesModule` in `PlansView.swift`**

In `Push/PlansView.swift`, replace the entire `YourPushesModule` struct with:

```swift
private struct YourPushesModule: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.currentPushesSpacing) {
            Text("Your Pushes")
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            if let first = viewModel.yourPushes.first {
                YourPushCard(plan: first) {
                    viewModel.managedPlan = first
                    viewModel.isManagePushPresented = true
                }
            }
            if viewModel.yourPushes.count > 1 {
                seeAllButton
            }
        }
    }

    private var seeAllButton: some View {
        Button {
            viewModel.isYourPushesPresented = true
        } label: {
            Text("See all \(viewModel.yourPushes.count) →")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .padding(.top, PlansLayout.reviewAllButtonTopPadding)
    }
}
```

- [ ] **Step 6: Wire `ManagePushView` cover into `PlansView.body`**

In `Push/PlansView.swift`, add a new `.fullScreenCover` after the existing `isYourPushesPresented` cover:

```swift
.fullScreenCover(isPresented: $viewModel.isManagePushPresented) {
    if let plan = viewModel.managedPlan {
        ManagePushView(plan: plan) {
            viewModel.isManagePushPresented = false
        }
    }
}
```

- [ ] **Step 7: Build and run in simulator**

⌘R. Navigate to the Pushes tab:
- "Your Pushes" section shows `YourPushCard` (not `ActivePlanCard`)
- Card shows title, walnut outline time chip, group · location, "Joined:" label with avatar circles, "4 going" + "Manage →"
- Tapping "Manage →" opens `ManagePushView` placeholder
- Tapping close on `ManagePushView` dismisses it

- [ ] **Step 8: Run full test suite**

⌘U. All tests pass.

- [ ] **Step 9: Commit**

```bash
git add Push/PlansViewModel.swift Push/PlansView.swift PushTests/PlansViewModelTests.swift
git commit -m "feat: wire YourPushCard and ManagePushView into Pushes screen"
```
