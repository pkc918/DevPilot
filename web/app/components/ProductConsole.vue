<template>
  <div class="console-orbit" data-parallax data-depth="1.4">
    <span class="orbit orbit-one" aria-hidden="true" />
    <span class="orbit orbit-two" aria-hidden="true" />
    <span class="orbit-node node-one"><i /> 5173</span>
    <span class="orbit-node node-two"><i /> TCP</span>
    <span class="orbit-node node-three"><i /> PID 14901</span>

    <div class="product-console">
      <div class="console-glare" aria-hidden="true" />
      <div class="console-titlebar">
        <div class="traffic-lights" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
        <span class="console-title">DEV_PILOT / LOCAL_RADAR</span>
        <span class="console-live"><i /> LIVE</span>
      </div>

      <div class="console-body">
        <aside class="console-sidebar">
          <div class="console-brandmark">&gt;_</div>
          <span class="sidebar-label">TOOLS</span>
          <div class="sidebar-item active"><i /> PORT</div>
          <div class="sidebar-footer">
            <span>v0.1.9</span>
            <i />
          </div>
        </aside>

        <div class="console-main">
          <div class="console-toolbar">
            <div>
              <span class="console-kicker">PORT MATRIX</span>
              <h2>项目服务</h2>
            </div>
            <div class="console-filter">
              <span class="active">项目</span>
              <span>全部</span>
            </div>
          </div>

          <div class="console-stats">
            <span><i class="green" /> 3 services online</span>
            <span>TCP 3</span>
            <span>UDP 0</span>
            <span class="sync">SYNC 00:03</span>
          </div>

          <div class="port-table">
            <div class="port-head">
              <span>PORT</span><span>PROCESS</span><span>PROJECT</span><span>STATUS</span>
            </div>
            <div class="port-row primary">
              <span class="port-number">5,173</span>
              <span><b class="process-dot violet" /> vite</span>
              <span class="project-path">~/code/DevPilot/web</span>
              <span class="status-tag">LISTEN</span>
            </div>
            <div class="port-row">
              <span class="port-number">3,000</span>
              <span><b class="process-dot blue" /> node</span>
              <span class="project-path">~/code/next-agent</span>
              <span class="status-tag">LISTEN</span>
            </div>
            <div class="port-row">
              <span class="port-number">8,080</span>
              <span><b class="process-dot green" /> go</span>
              <span class="project-path">~/code/api-gateway</span>
              <span class="status-tag">LISTEN</span>
            </div>
          </div>

          <div class="console-command">
            <span>&gt;</span>
            <span>scanning localhost</span>
            <i />
            <b>3 TARGETS</b>
          </div>
        </div>
      </div>
      <div class="scan-beam" aria-hidden="true" />
    </div>
  </div>
</template>
