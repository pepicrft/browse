defmodule BrowseTest do
  use ExUnit.Case, async: true

  defmodule FakeAdapter do
    @behaviour Browse.Adapter

    @impl Browse.Adapter
    def child_spec(opts) do
      %{id: Keyword.fetch!(opts, :name), start: {Task, :start_link, [fn -> :ok end]}}
    end

    @impl Browse.Adapter
    def start_link(opts) do
      send(self(), {:start_link, opts})
      Task.start_link(fn -> :ok end)
    end

    @impl Browse.Adapter
    def checkout(pool, fun, opts) do
      send(self(), {:checkout, pool, opts})
      fun.({:browser, pool})
    end

    @impl Browse.Adapter
    def navigate(browser, url, opts) do
      send(self(), {:navigate, browser, url, opts})
      :ok
    end

    @impl Browse.Adapter
    def current_url(browser) do
      send(self(), {:current_url, browser})
      {:ok, "https://example.com"}
    end

    @impl Browse.Adapter
    def content(browser) do
      send(self(), {:content, browser})
      {:ok, "<html></html>"}
    end

    @impl Browse.Adapter
    def evaluate(browser, script, opts) do
      send(self(), {:evaluate, browser, script, opts})
      {:ok, %{value: 42}}
    end

    @impl Browse.Adapter
    def capture_screenshot(browser, opts) do
      send(self(), {:capture_screenshot, browser, opts})
      {:ok, <<1, 2, 3>>}
    end

    @impl Browse.Adapter
    def print_to_pdf(browser, opts) do
      send(self(), {:print_to_pdf, browser, opts})
      {:ok, <<4, 5, 6>>}
    end

    @impl Browse.Adapter
    def click(browser, locator, opts) do
      send(self(), {:click, browser, locator, opts})
      :ok
    end

    @impl Browse.Adapter
    def fill(browser, locator, value, opts) do
      send(self(), {:fill, browser, locator, value, opts})
      :ok
    end

    @impl Browse.Adapter
    def wait_for(browser, locator, opts) do
      send(self(), {:wait_for, browser, locator, opts})
      :ok
    end
  end

  test "checkout delegates to the adapter" do
    assert {:ok, "https://example.com"} =
             Browse.checkout(
               FakeAdapter,
               :pool,
               fn browser ->
                 Browse.current_url(FakeAdapter, browser)
               end, timeout: 1_000)

    assert_received {:checkout, :pool, [timeout: 1_000]}
    assert_received {:current_url, {:browser, :pool}}
  end

  test "pool lifecycle helpers delegate to the adapter" do
    assert %{id: :pool} = Browse.child_spec(FakeAdapter, name: :pool)
    assert {:ok, pid} = Browse.start_link(FakeAdapter, name: :pool, size: 2)
    assert is_pid(pid)
    assert_received {:start_link, [name: :pool, size: 2]}
  end

  test "navigation and interaction helpers delegate to the adapter" do
    browser = {:browser, :pool}

    assert :ok = Browse.navigate(FakeAdapter, browser, "https://example.com", wait: true)
    assert {:ok, "<html></html>"} = Browse.content(FakeAdapter, browser)
    assert {:ok, %{value: 42}} = Browse.evaluate(FakeAdapter, browser, "1 + 1", await: true)
    assert {:ok, <<1, 2, 3>>} = Browse.capture_screenshot(FakeAdapter, browser, format: "jpeg")
    assert {:ok, <<4, 5, 6>>} = Browse.print_to_pdf(FakeAdapter, browser, scale: 2)
    assert :ok = Browse.click(FakeAdapter, browser, {:css, "button"}, timeout: 500)
    assert :ok = Browse.fill(FakeAdapter, browser, {:css, "input"}, "value", clear: true)
    assert :ok = Browse.wait_for(FakeAdapter, browser, {:text, "Loaded"}, visible: true)

    assert_received {:navigate, ^browser, "https://example.com", [wait: true]}
    assert_received {:content, ^browser}
    assert_received {:evaluate, ^browser, "1 + 1", [await: true]}
    assert_received {:capture_screenshot, ^browser, [format: "jpeg"]}
    assert_received {:print_to_pdf, ^browser, [scale: 2]}
    assert_received {:click, ^browser, {:css, "button"}, [timeout: 500]}
    assert_received {:fill, ^browser, {:css, "input"}, "value", [clear: true]}
    assert_received {:wait_for, ^browser, {:text, "Loaded"}, [visible: true]}
  end
end
