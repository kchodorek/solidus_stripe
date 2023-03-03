# frozen_string_literal: true

require 'stripe'

class SolidusStripe::IntentsController < Spree::BaseController
  include Spree::Core::ControllerHelpers::Order

  before_action :load_payment_method

  def payment_confirmation
    payment = @payment_method.find_in_progress_payment_for(current_order)
    intent = @payment_method.find_intent_for(payment)

    if params[:payment_intent] != intent.id
      raise "The payment intent id doesn't match"
    end

    unless %w[confirm payment].include?(current_order.state.to_s)
      redirect_to main_app.checkout_state_path(current_order.state)
      return
    end

    current_order.state = :payment
    SolidusStripe::LogEntries.payment_log(
      payment,
      success: true,
      message: "Reached return URL",
      data: intent,
    )

    # https://stripe.com/docs/payments/intents?intent=payment
    case intent.status
    when 'requires_payment_method'
      ensure_state_is(current_order, :payment)
      ensure_state_is(payment, :processing)
    when 'requires_confirmation', 'requires_action', 'processing'
      ensure_state_is(payment, :processing)
      current_order.next!
    when 'requires_capture'
      payment.pend! unless payment.pending?
      current_order.next!
      ensure_state_is(current_order, :confirm)
      ensure_state_is(payment, :pending)
    when 'succeeded'
      payment.completed! unless payment.completed?
      current_order.next!
      ensure_state_is(current_order, :confirm)
      ensure_state_is(payment, :completed)
    when 'canceled'
      payment.void! unless payment.void?
      ensure_state_is(current_order, :payment)
      ensure_state_is(payment, :void)
    else
      raise "unexpected intent status: #{intent.status}"
    end

    flash[:notice] = t(".intent_status.#{intent.status}")
    redirect_to main_app.checkout_state_path(current_order.state)
  end

  private

  def ensure_state_is(object, state)
    return if object.state.to_s == state.to_s

    raise "unexpected object state #{object.state}, should have been #{state}"
  end

  def load_payment_method
    @payment_method = current_order(create_order_if_necessary: true)
      .available_payment_methods.find(params[:payment_method_id])
  end
end