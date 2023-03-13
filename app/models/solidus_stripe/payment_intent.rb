# frozen_string_literal: true

module SolidusStripe
  class PaymentIntent < ApplicationRecord
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :payment_method, class_name: 'SolidusStripe::PaymentMethod'

    def self.retrieve_or_create_stripe_intent(payment_method:, order:)
      instance = find_or_initialize_by(payment_method: payment_method, order: order)

      if instance.stripe_intent_id
        instance.stripe_intent
      else
        instance.create_stripe_intent.tap { instance.update!(stripe_intent_id: _1.id) }
      end
    end

    def stripe_intent
      payment_method.gateway.request do
        Stripe::PaymentIntent.retrieve(stripe_intent_id)
      end
    end

    def create_stripe_intent
      customer = payment_method.customer_for(order)

      payment_method.gateway.request do
        Stripe::PaymentIntent.create({
          amount: payment_method.gateway.to_stripe_amount(
            order.display_total.money.fractional,
            order.currency,
          ),
          currency: order.currency,

          # The capture method should stay manual in order to
          # avoid capturing the money before the order is completed.
          capture_method: 'manual',
          setup_future_usage: payment_method.preferred_setup_future_usage.presence,
          customer: customer,
          metadata: { solidus_order_number: order.number },
        })
      end
    end
  end
end
