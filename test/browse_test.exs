defmodule BrowseTest do
  use ExUnit.Case, async: false

  def handle_telemetry(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end

  setup do
    original_default_pool = Application.get_env(:browse, :default_pool)
    original_pools = Application.get_env(:browse, :pools)
    telemetry_handler_id = "browse-test-#{System.unique_integer([:positive])}"

    Application.put_env(:browse, :pools,
      pool: [implementation: __MODULE__.FakeImplementation, pool_size: 1, test_pid: self()]
    )

    :ok =
      :telemetry.attach_many(
        telemetry_handler_id,
        [
          [:browse, :pool, :start, :start],
          [:browse, :pool, :start, :stop],
          [:browse, :checkout, :start],
          [:browse, :checkout, :stop],
          [:browse, :worker, :init, :start],
          [:browse, :worker, :init, :stop],
          [:browse, :worker, :remove],
          [:browse, :worker, :terminate]
        ],
        &__MODULE__.handle_telemetry/4,
        self()
      )

    on_exit(fn ->
      :telemetry.detach(telemetry_handler_id)

      if original_default_pool == nil do
        Application.delete_env(:browse, :default_pool)
      else
        Application.put_env(:browse, :default_pool, original_default_pool)
      end

      if original_pools == nil do
        Application.delete_env(:browse, :pools)
      else
        Application.put_env(:browse, :pools, original_pools)
      end
    end)

    :ok
  end

  defmodule FakeImplementation do
    @behaviour Browse.Browser

    @impl Browse.Browser
    def init(opts) do
      send(Keyword.fetch!(opts, :test_pid), {:init, opts})
      {:ok, %{pool: Keyword.fetch!(opts, :name)}}
    end

    @impl Browse.Browser
    def terminate(reason, state) do
      send(self(), {:terminate, reason, state})
      :ok
    end

    @impl Browse.Browser
    def navigate(browser, url, opts) do
      send(self(), {:navigate, browser, url, opts})
      :ok
    end

    @impl Browse.Browser
    def current_url(browser) do
      send(self(), {:current_url, browser})
      {:ok, "https://example.com"}
    end

    @impl Browse.Browser
    def content(browser) do
      send(self(), {:content, browser})
      {:ok, "<html></html>"}
    end

    @impl Browse.Browser
    def evaluate(browser, script, opts) do
      send(self(), {:evaluate, browser, script, opts})
      {:ok, %{value: 42}}
    end

    @impl Browse.Browser
    def capture_screenshot(browser, opts) do
      send(self(), {:capture_screenshot, browser, opts})
      {:ok, <<1, 2, 3>>}
    end

    @impl Browse.Browser
    def set_viewport(browser, width, height, opts) do
      send(self(), {:set_viewport, browser, width, height, opts})
      :ok
    end

    @impl Browse.Browser
    def print_to_pdf(browser, opts) do
      send(self(), {:print_to_pdf, browser, opts})
      {:ok, <<4, 5, 6>>}
    end

    @impl Browse.Browser
    def click(browser, locator, opts) do
      send(self(), {:click, browser, locator, opts})
      :ok
    end

    @impl Browse.Browser
    def fill(browser, locator, value, opts) do
      send(self(), {:fill, browser, locator, value, opts})
      :ok
    end

    @impl Browse.Browser
    def wait_for(browser, locator, opts) do
      send(self(), {:wait_for, browser, locator, opts})
      :ok
    end
  end

  test "Browse owns pool lifecycle" do
    assert %{id: :pool} = Browse.child_spec(:pool)
    assert {:ok, pid} = Browse.start_link(:pool)

    assert is_pid(pid)
    assert_received {:init, opts}
    assert Keyword.fetch!(opts, :name) == :pool
  end

  test "children builds child specs from configured pools" do
    assert [%{id: :pool, start: {Browse, :start_link, [:pool, _opts]}}] = Browse.children()
  end

  test "checkout uses the configured default pool" do
    Application.put_env(:browse, :default_pool, :pool)
    {:ok, _pid} = Browse.start_link(:pool)

    assert {:ok, "https://example.com"} =
             Browse.checkout(fn browser ->
               Browse.current_url(browser)
             end)

    assert_received {:current_url, %{pool: :pool}}
  end

  test "checkout yields an opaque browser handle" do
    {:ok, _pid} = Browse.start_link(:pool)

    assert {:ok, "https://example.com"} =
             Browse.checkout(:pool, fn browser ->
               Browse.current_url(browser)
             end)

    assert_received {:current_url, %{pool: :pool}}
  end

  test "browser capability helpers dispatch through the browser handle" do
    {:ok, _pid} = Browse.start_link(:pool)

    assert :ok =
             Browse.checkout(:pool, fn browser ->
               assert :ok = Browse.navigate(browser, "https://example.com", wait: true)
               assert {:ok, "<html></html>"} = Browse.content(browser)
               assert {:ok, %{value: 42}} = Browse.evaluate(browser, "1 + 1", await: true)
               assert {:ok, <<1, 2, 3>>} = Browse.capture_screenshot(browser, format: "jpeg")
               assert :ok = Browse.set_viewport(browser, 1280, 720, mobile: false)
               assert {:ok, <<4, 5, 6>>} = Browse.print_to_pdf(browser, scale: 2)
               assert :ok = Browse.click(browser, {:css, "button"}, timeout: 500)
               assert :ok = Browse.fill(browser, {:css, "input"}, "value", clear: true)
               assert :ok = Browse.wait_for(browser, {:text, "Loaded"}, visible: true)
               :ok
             end)

    assert_received {:navigate, %{pool: :pool}, "https://example.com", [wait: true]}
    assert_received {:content, %{pool: :pool}}
    assert_received {:evaluate, %{pool: :pool}, "1 + 1", [await: true]}
    assert_received {:capture_screenshot, %{pool: :pool}, [format: "jpeg"]}
    assert_received {:set_viewport, %{pool: :pool}, 1280, 720, [mobile: false]}
    assert_received {:print_to_pdf, %{pool: :pool}, [scale: 2]}
    assert_received {:click, %{pool: :pool}, {:css, "button"}, [timeout: 500]}
    assert_received {:fill, %{pool: :pool}, {:css, "input"}, "value", [clear: true]}
    assert_received {:wait_for, %{pool: :pool}, {:text, "Loaded"}, [visible: true]}
  end

  test "emits telemetry for pool startup, checkout, and worker lifecycle" do
    {:ok, _pid} = Browse.start_link(:pool)

    assert_received {:telemetry, [:browse, :pool, :start, :start], %{system_time: system_time}, %{pool: :pool}}

    assert is_integer(system_time)

    assert_received {:telemetry, [:browse, :worker, :init, :start], %{system_time: worker_system_time},
                     %{implementation: __MODULE__.FakeImplementation, pool: :pool}}

    assert is_integer(worker_system_time)

    assert_received {:telemetry, [:browse, :worker, :init, :stop], %{duration: worker_duration},
                     %{implementation: __MODULE__.FakeImplementation, pool: :pool}}

    assert is_integer(worker_duration)

    assert_received {:telemetry, [:browse, :pool, :start, :stop], %{duration: pool_duration},
                     %{
                       implementation: __MODULE__.FakeImplementation,
                       pid: pid,
                       pool: :pool,
                       pool_size: 1,
                       result: :ok
                     }}

    assert is_pid(pid)
    assert is_integer(pool_duration)

    assert :done =
             Browse.checkout(:pool, fn _browser ->
               {:done, :remove}
             end)

    assert_received {:telemetry, [:browse, :checkout, :start], %{system_time: checkout_system_time},
                     %{pool: :pool, timeout: 30_000}}

    assert is_integer(checkout_system_time)

    assert_received {:telemetry, [:browse, :checkout, :stop], %{duration: checkout_duration},
                     %{pool: :pool, timeout: 30_000}}

    assert is_integer(checkout_duration)

    assert_receive {:telemetry, [:browse, :worker, :remove], %{system_time: remove_system_time},
                    %{
                      implementation: __MODULE__.FakeImplementation,
                      pool: :pool,
                      reason: :checkout_remove
                    }}

    assert is_integer(remove_system_time)

    assert_receive {:telemetry, [:browse, :worker, :terminate], %{system_time: terminate_system_time},
                    %{
                      implementation: __MODULE__.FakeImplementation,
                      pool: :pool,
                      reason: :closed
                    }}

    assert is_integer(terminate_system_time)
  end
end
