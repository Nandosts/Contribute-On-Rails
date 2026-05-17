import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "lightIcon", "darkIcon" ]

  connect() {
    this.updateIcons()
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    if (isDark) {
      document.documentElement.classList.remove("dark")
      localStorage.setItem("theme", "light")
    } else {
      document.documentElement.classList.add("dark")
      localStorage.setItem("theme", "dark")
    }
    this.updateIcons()
  }

  updateIcons() {
    const isDark = document.documentElement.classList.contains("dark")
    if (isDark) {
      if (this.hasLightIconTarget) this.lightIconTarget.classList.remove("hidden")
      if (this.hasDarkIconTarget) this.darkIconTarget.classList.add("hidden")
    } else {
      if (this.hasLightIconTarget) this.lightIconTarget.classList.add("hidden")
      if (this.hasDarkIconTarget) this.darkIconTarget.classList.remove("hidden")
    }
  }
}
