defmodule BrowseTest do
  use ExUnit.Case, async: false

  setup do
    original_default_pool = Application.get_env(:browse, :default_pool)

    on_exit(fn ->
      if original_default_pool == nil do
        Application.delete_env(:browse, :default_pool)
      else
        Application.put_env(:browse, :default_pool, original_default_pool)
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
    assert %{id: :pool} = Browse.child_spec(FakeImplementation, name: :pool, pool_size: 1)

    assert {:ok, pid} =
             Browse.start_link(FakeImplementation, name: :pool, pool_size: 1, test_pid: self())

    assert is_pid(pid)
    assert_received {:init, opts}
    assert Keyword.fetch!(opts, :name) == :pool
  end

  test "checkout uses the configured default pool" do
    Application.put_env(:browse, :default_pool, :pool)
    {:ok, _pid} = Browse.start_link(FakeImplementation, name: :pool, pool_size: 1, test_pid: self())

    assert {:ok, "https://example.com"} =
             Browse.checkout(fn browser ->
               Browse.current_url(browser)
             end)

    assert_received {:current_url, %{pool: :pool}}
  end

  test "checkout yields an opaque browser handle" do
    {:ok, _pid} = Browse.start_link(FakeImplementation, name: :pool, pool_size: 1, test_pid: self())

    assert {:ok, "https://example.com"} =
             Browse.checkout(:pool, fn browser ->
               Browse.current_url(browser)
             end)

    assert_received {:current_url, %{pool: :pool}}
  end

  test "browser capability helpers dispatch through the browser handle" do
    {:ok, _pid} = Browse.start_link(FakeImplementation, name: :pool, pool_size: 1, test_pid: self())

    assert :ok =
             Browse.checkout(:pool, fn browser ->
               assert :ok = Browse.navigate(browser, "https://example.com", wait: true)
               assert {:ok, "<html></html>"} = Browse.content(browser)
               assert {:ok, %{value: 42}} = Browse.evaluate(browser, "1 + 1", await: true)
               assert {:ok, <<1, 2, 3>>} = Browse.capture_screenshot(browser, format: "jpeg")
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
    assert_received {:print_to_pdf, %{pool: :pool}, [scale: 2]}
    assert_received {:click, %{pool: :pool}, {:css, "button"}, [timeout: 500]}
    assert_received {:fill, %{pool: :pool}, {:css, "input"}, "value", [clear: true]}
    assert_received {:wait_for, %{pool: :pool}, {:text, "Loaded"}, [visible: true]}
  end
end
