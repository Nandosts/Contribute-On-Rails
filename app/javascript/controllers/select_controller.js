import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  connect() {
    this.tomSelect = new TomSelect(this.element, {
      create: false,
      allowEmptyOption: true,
      plugins: ["clear_button"],
    })
  }

  disconnect() {
    this.tomSelect?.destroy()
  }
}
