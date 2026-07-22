import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "content", "icon" ]
  static values = {
    projectId: Number,
    collapsed: { type: Boolean, default: false }
  }

  connect() {
    const savedState = localStorage.getItem(this.localStorageKey)
    if (savedState !== null) {
      this.collapsedValue = savedState === "true"
    }
    this.updateState()
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    localStorage.setItem(this.localStorageKey, this.collapsedValue)
    this.updateState()
  }

  updateState() {
    this.buttonTarget.setAttribute("aria-expanded", (!this.collapsedValue).toString())
    this.contentTarget.hidden = this.collapsedValue
    if (this.collapsedValue) {
      if (this.hasIconTarget) {
        this.iconTarget.classList.add("-rotate-90")
      }
    } else {
      if (this.hasIconTarget) {
        this.iconTarget.classList.remove("-rotate-90")
      }
    }
  }

  get localStorageKey() {
    return `collapsed-project-${this.projectIdValue}`
  }
}
