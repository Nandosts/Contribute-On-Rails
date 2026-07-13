import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "content", "icon" ]
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
    if (this.collapsedValue) {
      this.contentTarget.classList.add("hidden")
      if (this.hasIconTarget) {
        this.iconTarget.classList.add("-rotate-90")
      }
    } else {
      this.contentTarget.classList.remove("hidden")
      if (this.hasIconTarget) {
        this.iconTarget.classList.remove("-rotate-90")
      }
    }
  }

  get localStorageKey() {
    return `collapsed-project-${this.projectIdValue}`
  }
}
