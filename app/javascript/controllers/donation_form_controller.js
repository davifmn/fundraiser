import { Controller } from "@hotwired/stimulus"

// The donation form in two steps: the gift (preset or custom amount, once or monthly),
// then the donor's details. Without JavaScript both steps show as one plain form, and the
// server validates everything either way.
export default class extends Controller {
  static targets = ["step", "amount", "preset", "error", "summary"]

  connect() {
    this.element.classList.add("js")
    // After a failed submission, open the step that has the error.
    const detailsHaveErrors = this.element.querySelector(".errors") && this.validAmount()
    this.show(detailsHaveErrors ? 1 : 0)
    this.update()
  }

  choose({ params: { amount } }) {
    this.amountTarget.value = amount
    this.update()
  }

  update() {
    const amount = this.amountTarget.value.trim()
    this.presetTargets.forEach((button) => {
      button.classList.toggle("selected", button.dataset.donationFormAmountParam === amount)
    })
    if (this.validAmount()) {
      const monthly = this.element.querySelector("input[value=monthly]")?.checked
      this.summaryTarget.textContent = `You give ${this.format(amount)} ${monthly ? "every month" : "once"}.`
    }
  }

  next() {
    if (!this.validAmount()) {
      this.errorTarget.textContent = "Enter an amount between €1 and €10,000, with at most 2 decimals."
      this.errorTarget.hidden = false
      this.amountTarget.focus()
      return
    }
    this.errorTarget.hidden = true
    this.show(1)
    this.element.querySelector("input[name='donation[donor_name]']")?.focus()
  }

  back() {
    this.show(0)
  }

  // Same rule as the server (Donation#amount=): a plain decimal, €1 to €10,000.
  validAmount() {
    const value = this.amountTarget.value.trim()
    if (!/^\d{1,7}(\.\d{1,2})?$/.test(value)) return false
    const cents = Math.round(Number(value) * 100)
    return cents >= 100 && cents <= 1_000_000
  }

  format(amount) {
    return new Intl.NumberFormat("en-IE", { style: "currency", currency: "EUR" }).format(Number(amount))
  }

  show(index) {
    this.stepTargets.forEach((step, i) => {
      step.hidden = i !== index
    })
  }
}
