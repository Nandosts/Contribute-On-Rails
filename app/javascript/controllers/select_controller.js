import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  connect() {
    const plugins = ["clear_button"]
    if (this.element.multiple) {
      plugins.push("remove_button")
    }

    this.tomSelect = new TomSelect(this.element, {
      create: false,
      allowEmptyOption: true,
      plugins: plugins,
    })
    this.element.dataset.enhanced = "true"

    const wrapper = this.element.closest(".floating-label-group")
    if (wrapper) {
      this.updateState(wrapper)

      this.tomSelect.on("change", () => {
        this.updateState(wrapper)
        if (!this.element.multiple) {
          this.tomSelect.blur()
        }
      })
      this.tomSelect.on("focus", () => {
        wrapper.classList.add("is-focused")
      })
      this.tomSelect.on("blur", () => {
        wrapper.classList.remove("is-focused")
        this.updateState(wrapper)
      })
    }
  }

  updateState(wrapper) {
    if (this.element.value && this.element.value.trim() !== "") {
      wrapper.classList.add("has-value")
    } else {
      wrapper.classList.remove("has-value")
    }
  }

  disconnect() {
    this.tomSelect?.destroy()
  }
}
