# frozen_string_literal: true

require "solidus_stripe_spec_helper"

RSpec.describe SolidusStripe::Webhook::PaymentIntentSubscriber do
  describe "#complete_payment" do
    it "completes a pending payment" do
      payment_method = create(:stripe_payment_method)
      stripe_payment_intent = Stripe::PaymentIntent.construct_from(id: "pi_123")
      payment = create(:payment,
        payment_method: payment_method,
        response_code: stripe_payment_intent.id,
        state: "pending")
      event = SolidusStripe::Webhook::EventWithContextFactory.from_object(
        payment_method: payment_method,
        object: stripe_payment_intent,
        type: "payment_intent.succeeded"
      ).solidus_stripe_object

      described_class.new.complete_payment(event)

      expect(payment.reload.state).to eq "completed"
    end

    it "adds a log entry to the payment" do
      payment_method = create(:stripe_payment_method)
      stripe_payment_intent = Stripe::PaymentIntent.construct_from(id: "pi_123")
      payment = create(:payment,
        payment_method: payment_method,
        response_code: stripe_payment_intent.id,
        state: "pending")
      event = SolidusStripe::Webhook::EventWithContextFactory.from_object(
        payment_method: payment_method,
        object: stripe_payment_intent,
        type: "payment_intent.succeeded"
      ).solidus_stripe_object

      described_class.new.complete_payment(event)

      expect(
        payment.log_entries.last.parsed_details.message
      ).to eq "Capture was successful after payment_intent.succeeded webhook"
    end

    it "does nothing if the payment is already completed" do
      payment_method = create(:stripe_payment_method)
      stripe_payment_intent = Stripe::PaymentIntent.construct_from(id: "pi_123")
      payment = create(:payment,
        payment_method: payment_method,
        response_code: stripe_payment_intent.id,
        state: "completed")
      event = SolidusStripe::Webhook::EventWithContextFactory.from_object(
        payment_method: payment_method,
        object: stripe_payment_intent,
        type: "payment_intent.succeeded",
      ).solidus_stripe_object

      described_class.new.complete_payment(event)

      expect(payment.reload.state).to eq "completed"
      expect(payment.log_entries.count).to be(0)
    end
  end
end