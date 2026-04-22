# frozen_string_literal: true
module SpeedyAF
  class ProxyError < StandardError; end
  class ModelMismatch < ProxyError; end
  class RecordNotFound < ProxyError; end
end
