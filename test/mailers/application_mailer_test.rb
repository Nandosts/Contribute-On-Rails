require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  class MailerDeTeste < ApplicationMailer
    def boas_vindas
      mail(to: "teste@exemplo.com", subject: "Boas-vindas", body: "Olá")
    end
  end

  test "envia email usando layout e configuracao padrão do application mailer" do
    email = MailerDeTeste.boas_vindas.deliver_now
    assert_not ActionMailer::Base.deliveries.empty?
    assert_equal [ "from@example.com" ], email.from
    assert_equal [ "teste@exemplo.com" ], email.to
    assert_equal "Boas-vindas", email.subject
  end
end
